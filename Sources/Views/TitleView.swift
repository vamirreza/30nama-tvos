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
            else { ProgressView() }
        }
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

    private func content(_ t: Title) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 50) {
                HStack(alignment: .top, spacing: 60) {
                    AsyncImage(url: t.posterLarge) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color.white.opacity(0.08)
                    }
                    .frame(width: 360, height: 540)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    info(t)
                }
                if !t.directors.isEmpty || !t.cast.isEmpty { people(t) }
                if !seasonKeys.isEmpty { episodes }
            }
            .padding(80)
        }
        .background {
            ZStack {
                AsyncImage(url: t.cover) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color.clear
                }
                Color.black.opacity(0.78)
            }
            .ignoresSafeArea()
        }
    }

    private func info(_ t: Title) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(t.name).font(.system(size: 56, weight: .bold))
            if t.local != nil { Text(t.english).font(.title3).foregroundStyle(.secondary) }
            MetaLine(parts: [
                t.year.map { y in "\(y)" + (t.yearEnd.map { "–\($0)" } ?? "") } ?? "",
                t.minutes.map { "\($0) دقیقه" } ?? "",
                t.age ?? "",
                t.imdb.map { "IMDb \($0)" } ?? "",
                t.nama30.map { "سی‌نما \($0)" } ?? "",
                t.persianSubtitle ? "زیرنویس فارسی" : "",
            ])
            if !t.genres.isEmpty { Text(t.genres.joined(separator: "، ")).font(.callout).foregroundStyle(.secondary) }
            if let plot = t.plot { Text(plot).font(.body).lineLimit(6) }
            if let date = t.nextEpisodeDate {
                Text("\(t.nextEpisodeCaption ?? ""): \(date)").font(.callout).foregroundStyle(.secondary)
            }
            HStack(spacing: 24) {
                playButton(t)
                Button(lists.contains("watchlist", id) ? "✓ در لیست تماشا" : "+ لیست تماشا") { toggle("watchlist") }
                Button(lists.contains("favorite", id) ? "♥ علاقه‌مندی" : "♡ علاقه‌مندی") { toggle("favorite") }
            }
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func playButton(_ t: Title) -> some View {
        if t.canStream {
            if let r = stream?.resume, r.time > 0 {
                Button("▶ ادامه \(r.episodeName ?? "")") { router.play(id, fileId: r.fileId) }
                    .focused($playFocused)
            } else {
                Button("▶ پخش") { router.play(id) }
                    .focused($playFocused)
            }
        } else {
            Button(t.comingSoon ? "به‌زودی" : "پخش آنلاین ندارد") {}.disabled(true)
        }
    }

    private func people(_ t: Title) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 20) {
                ForEach(Array(t.directors.prefix(2).enumerated()), id: \.offset) { _, p in
                    personLink(p, role: "director", label: "کارگردان: \(p.name)")
                }
                ForEach(Array(t.cast.prefix(5).enumerated()), id: \.offset) { _, p in
                    personLink(p, role: "actor", label: p.name)
                }
            }
            .padding(.vertical, 20)
        }
        .scrollClipDisabled()
        .focusSection()
    }

    private func personLink(_ p: Person, role: String, label: String) -> some View {
        NavigationLink(value: Route.list(ListRoute(title: p.name, source: .person(role: role, name: p.name, imdb: p.imdb)))) {
            Text(label)
        }
    }

    private var episodes: some View {
        VStack(alignment: .leading, spacing: 20) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 20) {
                    ForEach(seasonKeys, id: \.self) { s in
                        ChipButton(label: "فصل \(s)", on: s == currentSeason) { season = s }
                    }
                }
                .padding(.vertical, 20)
            }
            .scrollClipDisabled()
            .focusSection()

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 20) {
                    ForEach(seasons[currentSeason] ?? []) { e in
                        Button { router.play(id, fileId: e.fileId) } label: {
                            VStack(spacing: 8) {
                                Text(e.episodeLabel).font(.title2.bold())
                                Text(e.episodeName ?? "").font(.caption).lineLimit(2)
                            }
                            .frame(width: 240, height: 120)
                        }
                    }
                }
                .padding(.vertical, 20)
            }
            .scrollClipDisabled()
            .focusSection()
        }
    }
}
