import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var router: Router
    @State private var home: HomeStream?
    @State private var continueList: [Title] = []
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
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
                    else { ProgressView().frame(maxWidth: .infinity).padding(120) }
                }
            }
        }
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

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            AsyncImage(url: title.cover) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.white.opacity(0.05)
            }
            .frame(maxWidth: .infinity, maxHeight: 680)
            .clipped()

            LinearGradient(colors: [.clear, .black.opacity(0.9)], startPoint: .top, endPoint: .bottom)

            VStack(alignment: .leading, spacing: 18) {
                Text(title.name).font(.vazir(64, .bold)).lineLimit(2)
                MetaLine(parts: [
                    title.year.map { "\($0)" } ?? "",
                    title.imdb.map { "IMDb \($0)" } ?? "",
                    title.age ?? "",
                ])
                if let plot = title.plot {
                    Text(plot).font(.appBody).lineLimit(3).frame(maxWidth: 1000, alignment: .leading)
                }
                HStack(spacing: 24) {
                    if title.isSeries {
                        NavigationLink(value: Route.title(title.id)) { Label("پخش", systemImage: "play.fill") }
                    } else {
                        Button { router.play(title.id) } label: { Label("پخش", systemImage: "play.fill") }
                    }
                    NavigationLink(value: Route.title(title.id)) { Text("جزئیات") }
                }
            }
            .padding(80)
        }
        .frame(height: 680)
        .focusSection()
    }
}
