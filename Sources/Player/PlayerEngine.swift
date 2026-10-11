import AVKit
import UIKit

/// Drives one playback session: resolves the stream, plays HLS, draws subtitles, offers
/// skip-intro / next-episode actions and reports progress back to 30nama.
@MainActor
final class PlayerEngine {
    private enum Contextual { case none, intro, nextAuto, nextManual }

    private let postId: Int
    private let startFileId: Int?
    private let userId: Int?
    private let settings: SettingsStore
    private let playerVC: AVPlayerViewController
    private let onClose: () -> Void

    private let player = AVPlayer()
    private var items: [StreamItem] = []
    private var index = 0
    private var resume: StreamResume?
    private var titleName = ""

    private var cues: [Cue] = []
    private var subLang: SubLang
    private var quality: Quality

    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var controlObservation: NSKeyValueObservation?
    private var lastReport: Double = 0
    private var contextual = Contextual.none
    private var autoNext = true
    private var nextDeadline: Double?
    private var closed = false

    #if os(iOS)
    private var chrome: PlayerChrome?
    #endif
    private let subtitleLabel = UILabel()
    private let statusLabel = UILabel()

    /// Countdown before the next episode starts on its own.
    private let autoNextSeconds: Double = 10
    /// Without a credits marker, the countdown starts this close to the end.
    private let tailSeconds: Double = 25

    init(postId: Int, fileId: Int?, userId: Int?, settings: SettingsStore, playerVC: AVPlayerViewController, onClose: @escaping () -> Void) {
        self.postId = postId
        self.startFileId = fileId
        self.userId = userId
        self.settings = settings
        self.playerVC = playerVC
        self.onClose = onClose
        self.subLang = settings.subLang
        self.quality = settings.quality
    }

    // MARK: lifecycle

    func start() {
        playerVC.player = player
        #if os(iOS)
        // Sound must play with the silent switch on, and Picture in Picture needs this category.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        try? AVAudioSession.sharedInstance().setActive(true)
        playerVC.allowsPictureInPicturePlayback = true
        #endif
        setupOverlay()
        showStatus("در حال بارگذاری…")

        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak self] time in
            let seconds = time.seconds
            Task { @MainActor in self?.tick(seconds) }
        }
        // Pausing is a natural moment to save the position.
        controlObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            guard player.timeControlStatus == .paused else { return }
            Task { @MainActor in self?.reportIfMoved() }
        }

        Task { await loadStream() }
    }

    func shutdown() {
        guard !closed else { return }
        reportProgress()
        closed = true
        player.pause()
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        timeObserver = nil
        controlObservation = nil
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = nil
        player.replaceCurrentItem(with: nil)
        setActions([])
    }

    private func loadStream() async {
        do {
            let s = try await API.stream(postId)
            guard !closed else { return }
            items = s.items
            resume = s.resume
            titleName = s.name
            guard !items.isEmpty else {
                showStatus("فایلی برای پخش پیدا نشد")
                return
            }
            // No explicit file means "resume": the stream's saved episode, else the first file.
            let target = startFileId ?? s.resume?.fileId
            let i = target.flatMap { t in items.firstIndex { $0.fileId == t } } ?? 0
            play(index: i)
        } catch {
            if let m = describe(error) { showStatus("خطای پخش: \(m)") }
        }
    }

    // MARK: playback

    private func play(index i: Int) {
        guard !closed, let item = items[safe: i] else { return }
        reportProgress()
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }

        index = i
        guard let source = item.sources.first else {
            showStatus("لینک پخش پیدا نشد")
            return
        }
        hideStatus()

        let playerItem = AVPlayerItem(url: source.url)
        applyQuality(to: playerItem)
        playerItem.externalMetadata = metadata(for: item)
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: playerItem, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.itemEnded() }
        }

        contextual = .none
        setActions([])
        autoNext = true
        nextDeadline = nil
        lastReport = 0

        player.replaceCurrentItem(with: playerItem)
        // Resume only the file the server saved a position for, and only once.
        if let r = resume, r.fileId == item.fileId, r.time > 0 {
            player.seek(to: CMTime(seconds: r.time, preferredTimescale: 600))
        }
        resume = nil
        player.play()

        loadCues()
        preferAudio(for: playerItem)
        rebuildMenus()
    }

    private func playNext() {
        guard items[safe: index + 1] != nil else { return }
        play(index: index + 1)
    }

    private func itemEnded() {
        guard !closed else { return }
        // A cancelled countdown means "stop here": the end returns to the title page.
        if autoNext, items[safe: index + 1] != nil { playNext() } else { onClose() }
    }

    private func skipIntro() {
        guard let end = items[safe: index]?.introEnd else { return }
        player.seek(to: CMTime(seconds: end, preferredTimescale: 600))
    }

    private func applyQuality(to item: AVPlayerItem) {
        let h = CGFloat(quality.rawValue)
        item.preferredMaximumResolution = quality == .auto ? .zero : CGSize(width: h * 16 / 9, height: h)
    }

    /// Each quality carries stereo and 5.1 audio groups; pick the one the viewer prefers.
    /// AVFoundation does not expose channel counts, so the option name is what is matched.
    private func preferAudio(for item: AVPlayerItem) {
        let wantSurround = settings.audio == .surround
        Task { [weak self] in
            guard let group = try? await item.asset.loadMediaSelectionGroup(for: .audible), group.options.count > 1 else { return }
            guard self != nil else { return }
            let match = group.options.first { option in
                let name = option.displayName.lowercased()
                let surround = name.contains("5.1") || name.contains("6ch") || name.contains("6 ch") || name.contains("surround")
                return surround == wantSurround
            }
            if let match { item.select(match, in: group) }
        }
    }

    // MARK: ticking

    private func tick(_ now: Double) {
        guard !closed, now.isFinite, let current = items[safe: index] else { return }

        let text = Subtitles.cue(at: now, in: cues)?.text
        if subtitleLabel.text != text { subtitleLabel.text = text }

        if abs(now - lastReport) >= Config.observerEveryS { reportProgress() }

        let duration = player.currentItem?.duration.seconds ?? .nan
        var inIntro = false
        if let end = current.introEnd { inIntro = now >= (current.introStart ?? 0) && now < end - 1 }
        var nearEnd = false
        if items[safe: index + 1] != nil, duration.isFinite, duration > 0 {
            nearEnd = current.creditsAt.map { now >= $0 } ?? (duration - now <= tailSeconds)
        }

        let want: Contextual = nearEnd ? (autoNext ? .nextAuto : .nextManual) : (inIntro ? .intro : .none)
        if want != contextual { setContextual(want) }

        // The countdown runs in playback time, so pausing pauses it.
        if nearEnd, autoNext, player.rate != 0 {
            if nextDeadline == nil { nextDeadline = now + autoNextSeconds }
            if let deadline = nextDeadline, now >= deadline { playNext() }
        } else if !nearEnd {
            nextDeadline = nil
        }
    }

    private func setContextual(_ state: Contextual) {
        contextual = state
        let next = UIAction(title: "قسمت بعد", image: UIImage(systemName: "forward.end.fill")) { [weak self] _ in self?.playNext() }
        switch state {
        case .none:
            setActions([])
        case .intro:
            setActions([
                UIAction(title: "رد کردن تیتراژ", image: UIImage(systemName: "forward.fill")) { [weak self] _ in self?.skipIntro() },
            ])
        case .nextAuto:
            setActions([
                next,
                UIAction(title: "ماندن") { [weak self] _ in self?.autoNext = false },
            ])
        case .nextManual:
            setActions([next])
        }
    }

    // MARK: progress

    private func reportIfMoved() {
        guard !closed, abs(player.currentTime().seconds - lastReport) > 1 else { return }
        reportProgress()
    }

    private func reportProgress() {
        guard let userId, let current = items[safe: index], let item = player.currentItem else { return }
        let t = player.currentTime().seconds
        guard t.isFinite, t > 0 else { return }
        lastReport = t
        let d = item.duration.seconds
        let postId = self.postId, fileId = current.fileId, token = current.token
        let time = Int(t), duration = d.isFinite ? Int(d) : 0
        Task { try? await API.observer(postId: postId, fileId: fileId, userId: userId, time: time, duration: duration, token: token) }
    }

    // MARK: subtitles

    private func loadCues() {
        cues = []
        subtitleLabel.text = nil
        guard subLang != .off, let current = items[safe: index] else { return }
        let url = subLang == .fa ? current.subtitleFa : current.subtitleEn
        guard let url else { return }
        let fileId = current.fileId, lang = subLang
        Task { [weak self] in
            let loaded = try? await Subtitles.load(url)
            guard let self, !self.closed, let loaded, self.subLang == lang, self.items[safe: self.index]?.fileId == fileId else { return }
            self.cues = loaded
        }
    }

    private func setSubLang(_ lang: SubLang) {
        subLang = lang
        settings.subLang = lang
        loadCues()
        rebuildMenus()
    }

    private func setQuality(_ q: Quality) {
        quality = q
        settings.quality = q
        if let item = player.currentItem { applyQuality(to: item) }
        rebuildMenus()
    }

    // MARK: UI

    private func metadata(for item: StreamItem) -> [AVMetadataItem] {
        func make(_ id: AVMetadataIdentifier, _ value: String) -> AVMetadataItem {
            let m = AVMutableMetadataItem()
            m.identifier = id
            m.value = value as NSString
            m.extendedLanguageTag = "und"
            return m
        }
        var out = [make(.commonIdentifierTitle, titleName)]
        if let episode = item.episodeName, !episode.isEmpty { out.append(make(.iTunesMetadataTrackSubTitle, episode)) }
        return out
    }

    private func rebuildMenus() {
        var menus: [UIMenuElement] = []

        if let current = items[safe: index], items.count > 1 {
            let season = current.season ?? 1
            let actions: [UIAction] = items.enumerated()
                .filter { ($0.element.season ?? 1) == season }
                .map { offset, e in
                    let label = "قسمت \(e.episodeLabel)" + ((e.episodeName?.isEmpty == false) ? " — \(e.episodeName ?? "")" : "")
                    return UIAction(title: label, state: offset == index ? .on : .off) { [weak self] _ in
                        guard let self, offset != self.index else { return }
                        self.play(index: offset)
                    }
                }
            menus.append(UIMenu(title: "قسمت‌ها", image: UIImage(systemName: "list.bullet"), children: actions))
        }

        let subs: [UIAction] = SubLang.allCases.map { l in
            UIAction(title: l.label, state: l == subLang ? .on : .off) { [weak self] _ in self?.setSubLang(l) }
        }
        menus.append(UIMenu(title: "زیرنویس", image: UIImage(systemName: "captions.bubble"), children: subs))

        let qualities: [UIAction] = Quality.allCases.map { q in
            UIAction(title: q.label, state: q == quality ? .on : .off) { [weak self] _ in self?.setQuality(q) }
        }
        menus.append(UIMenu(title: "کیفیت", image: UIImage(systemName: "slider.horizontal.3"), children: qualities))

        setMenus(menus)
    }

    // The transport bar's custom menus and contextual actions are tvOS-only; on iPhone the same
    // elements feed PlayerChrome instead.
    private func setActions(_ actions: [UIAction]) {
        #if os(tvOS)
        playerVC.contextualActions = actions
        #else
        chrome?.setActions(actions)
        #endif
    }

    private func setMenus(_ menus: [UIMenuElement]) {
        #if os(tvOS)
        playerVC.transportBarCustomMenuItems = menus
        #else
        chrome?.setMenus(menus)
        #endif
    }

    #if os(tvOS)
    private let statusFontSize: CGFloat = 36
    #else
    private let statusFontSize: CGFloat = 16
    #endif

    private func setupOverlay() {
        playerVC.loadViewIfNeeded()
        guard let overlay = playerVC.contentOverlayView else { return }

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.numberOfLines = 0
        subtitleLabel.textAlignment = .center
        subtitleLabel.textColor = .white
        subtitleLabel.font = Vazir.uiFont(settings.subSize.pointSize, .semibold)
        subtitleLabel.layer.shadowColor = UIColor.black.cgColor
        subtitleLabel.layer.shadowOpacity = 1
        subtitleLabel.layer.shadowRadius = 5
        subtitleLabel.layer.shadowOffset = .zero
        overlay.addSubview(subtitleLabel)

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.numberOfLines = 0
        statusLabel.textAlignment = .center
        statusLabel.textColor = .white
        statusLabel.font = Vazir.uiFont(statusFontSize, .medium)
        statusLabel.isHidden = true
        overlay.addSubview(statusLabel)

        #if os(tvOS)
        let sideInset: CGFloat = 200, subtitleLift: CGFloat = 140
        #else
        let sideInset: CGFloat = 40, subtitleLift: CGFloat = 56
        #endif
        NSLayoutConstraint.activate([
            subtitleLabel.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            subtitleLabel.bottomAnchor.constraint(equalTo: overlay.bottomAnchor, constant: -subtitleLift),
            subtitleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: overlay.leadingAnchor, constant: sideInset),
            subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: overlay.trailingAnchor, constant: -sideInset),
            statusLabel.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
            statusLabel.leadingAnchor.constraint(greaterThanOrEqualTo: overlay.leadingAnchor, constant: sideInset),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: overlay.trailingAnchor, constant: -sideInset),
        ])

        #if os(iOS)
        if let host = playerVC.parent?.view {
            let chrome = PlayerChrome(onClose: onClose)
            host.addSubview(chrome)
            NSLayoutConstraint.activate([
                chrome.leadingAnchor.constraint(equalTo: host.leadingAnchor),
                chrome.trailingAnchor.constraint(equalTo: host.trailingAnchor),
                chrome.topAnchor.constraint(equalTo: host.topAnchor),
                chrome.bottomAnchor.constraint(equalTo: host.bottomAnchor),
            ])
            // A tap anywhere brings the close and menu buttons back for a few seconds.
            let tap = UITapGestureRecognizer(target: chrome, action: #selector(PlayerChrome.pulse))
            tap.cancelsTouchesInView = false
            tap.delegate = chrome
            host.addGestureRecognizer(tap)
            self.chrome = chrome
        }
        #endif
    }

    private func showStatus(_ text: String) {
        statusLabel.text = text
        statusLabel.isHidden = false
    }

    private func hideStatus() { statusLabel.isHidden = true }
}
