import SwiftUI

struct TitleView: View {
    let id: Int
    @EnvironmentObject private var router: Router
    @State private var title: Title?
    @State private var stream: StreamInfo?
    @State private var lists = MyLists()
    @State private var error: String?
    @State private var season: Int?
    @FocusState private var playFocused: Bool

    var body: some View {
        ZStack {
            if let t = title { content(t) }
            else if let error { ErrorNote(message: error) { Task { await load() } } }
            else { ProgressView().tint(Theme.red) }
        }
        .background(AppBackground())
        .task { await load() }
        // Back from the player: the saved position has moved.
        .onChange(of: router.player == nil) { _, closed in
            if closed { Task { await refreshStream() } }
        }
    }

    // MARK: data

    private func load() async {
        do {
            error = nil
            let t = try await API.single(id)
            title = t
            // The tab bar above would otherwise keep focus after the push; start on Play.
            try? await Task.sleep(nanoseconds: 150_000_000)
            playFocused = true
            lists = (try? await API.myLists()) ?? lists
            if t.canStream && t.isSeries { await refreshStream() }
        } catch {
            self.error = describe(error)
        }
    }

    private func refreshStream() async {
        guard let t = title, t.canStream, t.isSeries else { return }
        if let s = try? await API.stream(id) { stream = s }
    }

    // MARK: seasons

    private var seasons: [Int: [StreamItem]] { Dictionary(grouping: stream?.items ?? [], by: { $0.season ?? 1 }) }
    private var seasonKeys: [Int] { seasons.keys.sorted() }
    private var currentSeason: Int {
        if let s = season { return s }
        if let r = stream?.resume?.season, r > 0 { return r }
        return seasonKeys.first ?? 1
    }

    private func toggle(_ group: String) {
        let was = lists.contains(group, id)
        lists.set(group, id, !was)
        Task {
            try? await API.toggleList(group, id)
            if let fresh = try? await API.myLists() { lists = fresh }
        }
    }

    // MARK: layout

    private func poster(_ t: Title) -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
        return AsyncImage(url: t.posterLarge) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            Theme.card
        }
        .frame(width: Metrics.titlePosterWidth, height: Metrics.titlePosterHeight)
        .clipShape(shape)
        .overlay(shape.strokeBorder(Theme.stroke, lineWidth: 1))
        .shadow(color: .black.opacity(0.55), radius: 30, y: 16)
    }

    @ViewBuilder
    private func header(_ t: Title) -> some View {
        #if os(tvOS)
        HStack(alignment: .top, spacing: 60) {
            poster(t)
            info(t)
        }
        #else
        VStack(alignment: .leading, spacing: 18) {
            poster(t).frame(maxWidth: .infinity)
            info(t)
        }
        #endif
    }

    private func content(_ t: Title) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.sectionGap) {
                header(t)
                if !t.directors.isEmpty || !t.cast.isEmpty { people(t) }
                if !seasonKeys.isEmpty { episodes }
            }
            .padding(Metrics.pagePad)
        }
        .background { backdrop(t) }
    }

    /// The cover fades out into the brand background instead of being dimmed flat.
    private func backdrop(_ t: Title) -> some View {
        ZStack(alignment: .top) {
            AppBackground()
            GeometryReader { geo in
                AsyncImage(url: t.cover) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color.clear
                }
                .frame(width: geo.size.width, height: geo.size.height * 0.8, alignment: .top)
                .clipped()
                .overlay(LinearGradient(colors: [Theme.background.opacity(0.55), Theme.background], startPoint: .top, endPoint: .bottom))
                .overlay(LinearGradient(colors: [Theme.background.opacity(0.8), .clear], startPoint: .leading, endPoint: .trailing))
            }
        }
        .ignoresSafeArea()
    }

    private func watchlistButton(wide: Bool) -> some View {
        Button { toggle("watchlist") } label: {
            Label(lists.contains("watchlist", id) ? "در لیست تماشا" : "لیست تماشا", systemImage: lists.contains("watchlist", id) ? "checkmark" : "plus")
                .lineLimit(1)
                .frame(maxWidth: wide ? CGFloat.infinity : nil)
        }
        .buttonStyle(.pill)
    }

    private func favoriteButton(wide: Bool) -> some View {
        Button { toggle("favorite") } label: {
            Label("علاقه‌مندی", systemImage: lists.contains("favorite", id) ? "heart.fill" : "heart")
                .lineLimit(1)
                .frame(maxWidth: wide ? CGFloat.infinity : nil)
        }
        .buttonStyle(.pill)
    }

    @ViewBuilder
    private func actions(_ t: Title) -> some View {
        #if os(tvOS)
        HStack(spacing: 24) {
            playButton(t, wide: false)
            watchlistButton(wide: false)
            favoriteButton(wide: false)
        }
        #else
        VStack(spacing: 10) {
            playButton(t, wide: true)
            HStack(spacing: 10) {
                watchlistButton(wide: true)
                favoriteButton(wide: true)
            }
        }
        #endif
    }

    private func info(_ t: Title) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(t.name).font(.appTitleLarge)
            if t.local != nil { Text(t.english).font(.appTitle3).foregroundStyle(Theme.textDim) }
            MetaBadges(title: t)
            if !t.genres.isEmpty { genres(t.genres) }
            if let plot = t.plot { Text(plot).font(.appBody).foregroundStyle(Color.white.opacity(0.88)).lineLimit(6) }
            if let date = t.nextEpisodeDate {
                Label("\(t.nextEpisodeCaption ?? ""): \(date)", systemImage: "calendar")
                    .font(.appCallout)
                    .foregroundStyle(Theme.textDim)
            }
            actions(t)
                .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func genres(_ list: [String]) -> some View {
        let row = HStack(spacing: Metrics.itemSpacing) {
            ForEach(list, id: \.self) { g in
                Text(g)
                    .font(.appCallout)
                    .padding(.horizontal, Theme.chipH).padding(.vertical, Theme.chipV / 2)
                    .background(Theme.card, in: Capsule())
                    .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
            }
        }
        return ViewThatFits(in: .horizontal) {
            row
            ScrollView(.horizontal, showsIndicators: false) { row }
        }
    }

    @ViewBuilder
    private func playButton(_ t: Title, wide: Bool) -> some View {
        let width: CGFloat? = wide ? CGFloat.infinity : nil
        if t.canStream {
            if let r = stream?.resume, r.time > 0 {
                Button { router.play(id, fileId: r.fileId) } label: {
                    Label("ادامه \(r.episodeName ?? "")", systemImage: "play.fill").frame(maxWidth: width)
                }
                .buttonStyle(.pillProminent)
                .focused($playFocused)
            } else {
                Button { router.play(id) } label: {
                    Label("پخش", systemImage: "play.fill").frame(maxWidth: width)
                }
                .buttonStyle(.pillProminent)
                .focused($playFocused)
            }
        } else {
            Button(t.comingSoon ? "به‌زودی" : "پخش آنلاین ندارد") {}
                .buttonStyle(.pill)
                .disabled(true)
        }
    }

    private func people(_ t: Title) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "بازیگران و سازندگان")
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: Metrics.itemSpacing) {
                    ForEach(Array(t.directors.prefix(2).enumerated()), id: \.offset) { _, p in
                        personLink(p, role: "director", label: "کارگردان: \(p.name)", icon: "megaphone.fill")
                    }
                    ForEach(Array(t.cast.prefix(5).enumerated()), id: \.offset) { _, p in
                        personLink(p, role: "actor", label: p.name, icon: "person.fill")
                    }
                }
                .padding(.vertical, 16)
            }
            .rowClipDisabled()
        }
        .tvFocusSection()
    }

    private func personLink(_ p: Person, role: String, label: String, icon: String) -> some View {
        NavigationLink(value: Route.list(ListRoute(title: p.name, source: .person(role: role, name: p.name, imdb: p.imdb)))) {
            Label(label, systemImage: icon)
        }
        .buttonStyle(ChipButtonStyle())
    }

    private func episodeCard(_ e: StreamItem) -> some View {
        let isResume = stream?.resume?.fileId == e.fileId
        return Button { router.play(id, fileId: e.fileId) } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(e.episodeLabel).font(.appTitle2).foregroundStyle(Theme.red)
                    Spacer()
                    Image(systemName: isResume ? "play.circle.fill" : "play.circle")
                        .font(.appTitle3)
                        .foregroundStyle(isResume ? Theme.red : Theme.textDim)
                }
                Text(e.episodeName ?? "").font(.appCaption).lineLimit(2).foregroundStyle(Color.white.opacity(0.85))
                Spacer(minLength: 0)
            }
            .padding(Metrics.cardPad * 0.6)
            .frame(width: Metrics.episodeWidth, height: Metrics.episodeHeight, alignment: .topLeading)
            .background(Theme.card)
        }
        .buttonStyle(PosterButtonStyle(radius: Theme.radius * 0.8))
    }

    private var episodes: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "قسمت‌ها")
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: Metrics.itemSpacing) {
                    ForEach(seasonKeys, id: \.self) { s in
                        ChipButton(label: "فصل \(s)", on: s == currentSeason) { season = s }
                    }
                }
                .padding(.vertical, 12)
            }
            .rowClipDisabled()
            .tvFocusSection()

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: Metrics.rowGap) {
                    ForEach(seasons[currentSeason] ?? []) { e in episodeCard(e) }
                }
                .padding(.vertical, 20)
            }
            .rowClipDisabled()
            .tvFocusSection()
        }
    }
}
