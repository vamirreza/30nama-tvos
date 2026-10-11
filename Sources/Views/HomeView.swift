import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var router: Router
    @State private var home: HomeStream?
    @State private var continueList: [Title] = []
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.rowVPad) {
                if let hero = home?.hero.first { Hero(title: hero) }
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
            } catch {
                self.error = describe(error)
            }
        }
        if let page = await cw { continueList = page.posts }
    }
}

private struct Hero: View {
    @EnvironmentObject private var router: Router
    let title: Title

    private var backdrop: some View {
        ZStack {
            AsyncImage(url: title.cover) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Theme.card
            }
            // Text side first, then a fade into the page so the rows below connect seamlessly.
            LinearGradient(colors: [Theme.background.opacity(0.92), Theme.background.opacity(0.35), .clear], startPoint: .leading, endPoint: .trailing)
            LinearGradient(stops: [
                .init(color: .clear, location: 0.35),
                .init(color: Theme.background.opacity(0.7), location: 0.75),
                .init(color: Theme.background, location: 1),
            ], startPoint: .top, endPoint: .bottom)
        }
    }

    private var playButton: some View {
        Group {
            if title.isSeries {
                NavigationLink(value: Route.title(title.id)) { Label("پخش", systemImage: "play.fill") }
            } else {
                Button { router.play(title.id) } label: { Label("پخش", systemImage: "play.fill") }
            }
        }
        .buttonStyle(.pillProminent)
    }

    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: Metrics.heroHeight)
            // The image fills an overlay, so its fill-scaled width cannot widen the page.
            .overlay { backdrop }
            .overlay(alignment: .topLeading) { Logo().padding(Metrics.heroLogoPad) }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: Metrics.itemSpacing) {
                    Text(title.name).font(.appTitle).lineLimit(2)
                    MetaBadges(title: title)
                    if let plot = title.plot {
                        Text(plot)
                            .font(.appBody)
                            .foregroundStyle(Color.white.opacity(0.85))
                            .lineLimit(3)
                            .frame(maxWidth: Metrics.heroTextWidth, alignment: .leading)
                    }
                    HStack(spacing: Metrics.itemSpacing) {
                        playButton
                        NavigationLink(value: Route.title(title.id)) { Label("جزئیات", systemImage: "info.circle") }
                            .buttonStyle(.pill)
                    }
                    .padding(.top, 6)
                }
                .padding(Metrics.pagePad)
            }
            .clipped()
            .tvFocusSection()
    }
}
