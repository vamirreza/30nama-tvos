import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var router: Router
    @State private var home: HomeStream?
    @State private var continueList: [Title] = []
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.rowVPad) {
                if let h = home, !h.hero.isEmpty { HeroCarousel(titles: Array(h.hero.prefix(8))) }
                TitleRow(title: tr("ادامه تماشا"), items: continueList) { router.play($0.id) }
                if let h = home {
                    TitleRow(title: tr("پیشنهاد ویژه"), items: h.hero)
                    TitleRow(title: tr("پیشنهادی"), items: h.suggested)
                    TitleRow(title: tr("فیلم"), items: h.movies)
                    TitleRow(title: tr("سریال"), items: h.series)
                    TitleRow(title: tr("انیمه"), items: h.anime)
                }
                if home == nil {
                    if let error { ErrorNote(message: error) { Task { await load() } } }
                    else { LaunchView().frame(height: 600) }
                }
            }
        }
        #if os(iOS)
        .background(Theme.background.ignoresSafeArea())
        #else
        .appBackground()
        #endif
        .task { await load() }
    }

    private func load() async {
        // Continue watching is cheap and changes after every viewing, so it refreshes each visit.
        async let cw = try? API.continueWatching()
        if home == nil {
            do {
                error = nil
                home = try await API.homeStream()
                if let h = home {
                    var seen = Set<Int>()
                    TopShelfStore.save((h.hero + h.suggested + h.movies + h.series + h.anime).filter { seen.insert($0.id).inserted })
                }
            } catch {
                self.error = describe(error)
            }
        }
        if let page = await cw { continueList = page.posts }
    }
}

/// The featured titles, one at a time: auto-advances and the dots show where it is.
private struct HeroCarousel: View {
    let titles: [Title]
    @State private var index = 0
    @State private var tick = 0   // restarts the timer after a manual change
    private let interval: UInt64 = 7_000_000_000

    private func go(_ i: Int) {
        withAnimation(.easeInOut(duration: 0.5)) { index = (i + titles.count) % titles.count }
        tick += 1
    }

    var body: some View {
        pager
            .frame(height: Metrics.heroHeight)
            .overlay(alignment: .bottom) { dots.padding(.bottom, Metrics.heroDotsPad) }
            .tvFocusSection()
            .task(id: tick) {
                guard titles.count > 1 else { return }
                try? await Task.sleep(nanoseconds: interval)
                if !Task.isCancelled { go(index + 1) }
            }
    }

    @ViewBuilder private var pager: some View {
        #if os(iOS)
        // Real paging: the next poster follows the finger.
        TabView(selection: $index) {
            ForEach(Array(titles.enumerated()), id: \.offset) { i, t in
                PhoneHero(title: t).tag(i)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .onChange(of: index) { _, _ in tick += 1 }
        #else
        ZStack {
            ForEach(Array(titles.enumerated()), id: \.offset) { i, t in
                if i == index { Hero(title: t).id(t.id).transition(.opacity) }
            }
        }
        #endif
    }

    private var dots: some View {
        HStack(spacing: 8) {
            ForEach(titles.indices, id: \.self) { i in
                Capsule()
                    .fill(i == index ? Color.white : Color.white.opacity(0.35))
                    .frame(width: i == index ? Metrics.dotActive : Metrics.dot, height: Metrics.dot)
                    .onTapGesture { go(i) }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(.black.opacity(0.25), in: Capsule())
        .animation(.easeInOut(duration: 0.3), value: index)
        .environment(\.layoutDirection, .leftToRight)
    }
}

#if os(iOS)
/// iPhone hero in the style of the Apple TV app: a tall poster running under the status bar,
/// with the title, details and Play centered over its fade.
private struct PhoneHero: View {
    @EnvironmentObject private var router: Router
    let title: Title

    private var details: String {
        (title.genres.prefix(2).map { $0 } + [title.year.map { "\($0)" } ?? "", title.age ?? ""]).filter { !$0.isEmpty }.joined(separator: " · ")
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.background
            Color.clear.overlay {
                RemoteImage(url: title.posterBig ?? title.cover, maxPixel: 1400) {
                    Color.white.opacity(0.05)
                }
            }
            .clipped()
            // Dissolve into the page at both ends: the top under the status bar, the bottom behind the text.
            .mask(LinearGradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: .black.opacity(0.85), location: 0.14),
                .init(color: .black, location: 0.3),
                .init(color: .black.opacity(0.9), location: 0.55),
                .init(color: .black.opacity(0.35), location: 0.78),
                .init(color: .clear, location: 1),
            ], startPoint: .top, endPoint: .bottom))

            VStack(spacing: 12) {
                if title.persianSubtitle { Badge(text: tr("زیرنویس فارسی"), kind: .glass, icon: "captions.bubble.fill") }
                Text(title.name)
                    .font(.appTitle2).multilineTextAlignment(.center).lineLimit(2)
                    .shadow(color: .black.opacity(0.7), radius: 10)
                HStack(spacing: 10) {
                    if let s = title.imdb, s > 0 { Badge(text: "IMDb \(s)", kind: .imdb) }
                    Text(details).font(.appCallout).foregroundStyle(Theme.textDim).lineLimit(1)
                }
                HStack(spacing: 12) {
                    if title.isSeries {
                        NavigationLink(value: Route.title(title.id)) { playLabel }.buttonStyle(.plain)
                    } else {
                        Button { router.play(title.id) } label: { playLabel }.buttonStyle(.plain)
                    }
                    NavigationLink(value: Route.title(title.id)) {
                        Image(systemName: "info")
                            .font(.system(size: 20, weight: .semibold))
                            .frame(width: 50, height: 50)
                            .background(Color.white.opacity(0.2), in: Circle())
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tr("جزئیات"))
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, Metrics.pagePad)
            .padding(.bottom, 52)
        }
    }

    private var playLabel: some View {
        Label(tr("پخش"), systemImage: "play.fill")
            .font(.appHeadline)
            .foregroundStyle(.black)
            .frame(width: 190, height: 50)
            .background(Color.white, in: Capsule())
    }
}
#endif

private struct Hero: View {
    @EnvironmentObject private var router: Router
    let title: Title

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // The image fills an overlay, so its fill-scaled width cannot widen the page.
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: Metrics.heroHeight)
                .overlay {
                    RemoteImage(url: title.cover, maxPixel: 1920) {
                        Color.white.opacity(0.05)
                    }
                }
                .clipped()

            // Reads on any artwork: dark at the bottom for text, dark at the leading edge, and a fade into the page.
            LinearGradient(colors: [.clear, Theme.background.opacity(0.55), Theme.background], startPoint: .init(x: 0.5, y: 0.2), endPoint: .bottom)
            LinearGradient(colors: [Theme.background.opacity(0.75), .clear], startPoint: .leading, endPoint: .init(x: 0.7, y: 0.5))

            VStack(alignment: .leading, spacing: Metrics.itemSpacing) {
                Text(title.name).font(.appTitle).lineLimit(2).shadow(color: .black.opacity(0.6), radius: 8)
                MetaBadges(title: title)
                if let plot = title.plot {
                    Text(plot).font(.appBody).foregroundStyle(Theme.textDim).lineLimit(Metrics.heroPlotLines)
                        .frame(maxWidth: Metrics.heroTextWidth, alignment: .leading)
                }
                HStack(spacing: Metrics.itemSpacing) {
                    if title.isSeries {
                        NavigationLink(value: Route.title(title.id)) { Label(tr("پخش"), systemImage: "play.fill") }
                            .buttonStyle(.pillProminent)
                    } else {
                        Button { router.play(title.id) } label: { Label(tr("پخش"), systemImage: "play.fill") }
                            .buttonStyle(.pillProminent)
                    }
                    NavigationLink(value: Route.title(title.id)) { Label(tr("جزئیات"), systemImage: "info.circle") }
                        .buttonStyle(.pill)
                }
                .padding(.bottom, Metrics.heroButtonsBottom)
            }
            .padding(.horizontal, Metrics.pagePad)
            .padding(.bottom, Metrics.pagePad * 0.5)
        }
        .frame(height: Metrics.heroHeight)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius * 1.8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius * 1.8, style: .continuous).strokeBorder(Theme.stroke, lineWidth: 1))
        .padding(.horizontal, Metrics.pagePad * 0.5)
    }
}
