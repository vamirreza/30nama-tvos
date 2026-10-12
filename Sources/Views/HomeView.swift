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
                TitleRow(title: "ادامه تماشا", items: continueList) { router.play($0.id) }
                if let h = home {
                    TitleRow(title: "پیشنهاد ویژه", items: h.hero)
                    TitleRow(title: "پیشنهادی", items: h.suggested)
                    TitleRow(title: "فیلم", items: h.movies)
                    TitleRow(title: "سریال", items: h.series)
                    TitleRow(title: "انیمه", items: h.anime)
                }
                if home == nil {
                    if let error { ErrorNote(message: error) { Task { await load() } } }
                    else { LaunchView().frame(height: 600) }
                }
            }
        }
        .appBackground()
        .task { await load() }
    }

    private func load() async {
        // Continue watching is cheap and changes after every viewing, so it refreshes each visit.
        async let cw = try? API.continueWatching()
        if home == nil {
            do {
                error = nil
                home = try await API.homeStream()
                if let hero = home?.hero { TopShelfStore.save(hero) }
            } catch {
                self.error = describe(error)
            }
        }
        if let page = await cw { continueList = page.posts }
    }
}

/// The featured titles, one at a time: auto-advances, swipes on iPhone, and the dots show where it is.
private struct HeroCarousel: View {
    let titles: [Title]
    @State private var index = 0
    @State private var tick = 0   // restarts the timer after a manual change
    private let interval: UInt64 = 7_000_000_000

    private func go(_ i: Int) {
        withAnimation(.easeInOut(duration: 0.6)) { index = (i + titles.count) % titles.count }
        tick += 1
    }

    var body: some View {
        ZStack {
            ForEach(Array(titles.enumerated()), id: \.offset) { i, t in
                if i == index { Hero(title: t).id(t.id).transition(.opacity) }
            }
        }
        .frame(height: Metrics.heroHeight)
        .overlay(alignment: .bottom) { dots.padding(.bottom, Metrics.heroDotsPad) }
        .tvFocusSection()
        #if os(iOS)
        .gesture(DragGesture(minimumDistance: 30).onEnded { v in
            if abs(v.translation.width) > abs(v.translation.height) { go(index + (v.translation.width < 0 ? 1 : -1)) }
        })
        #endif
        .task(id: tick) {
            guard titles.count > 1 else { return }
            try? await Task.sleep(nanoseconds: interval)
            if !Task.isCancelled { go(index + 1) }
        }
    }

    private var dots: some View {
        HStack(spacing: 8) {
            ForEach(titles.indices, id: \.self) { i in
                Capsule()
                    .fill(i == index ? Theme.red : Color.white.opacity(0.35))
                    .frame(width: i == index ? Metrics.dotActive : Metrics.dot, height: Metrics.dot)
                    .onTapGesture { go(i) }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: index)
        .environment(\.layoutDirection, .leftToRight)
    }
}

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
                    AsyncImage(url: title.cover) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
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
                        NavigationLink(value: Route.title(title.id)) { Label("پخش", systemImage: "play.fill") }
                            .buttonStyle(.pillProminent)
                    } else {
                        Button { router.play(title.id) } label: { Label("پخش", systemImage: "play.fill") }
                            .buttonStyle(.pillProminent)
                    }
                    NavigationLink(value: Route.title(title.id)) { Label("جزئیات", systemImage: "info.circle") }
                        .buttonStyle(.pill)
                }
                .padding(.bottom, Metrics.heroButtonsBottom)
            }
            .padding(.horizontal, Metrics.pagePad)
            .padding(.bottom, Metrics.pagePad * 0.5)
        }
        .frame(height: Metrics.heroHeight)
    }
}
