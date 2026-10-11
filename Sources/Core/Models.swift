import Foundation

struct Person: Hashable {
    let name: String
    let imdb: String?
}

/// One shape for home rows, search, archive, lists and detail.
struct Title: Identifiable {
    let id: Int
    let titleType: String
    let canStream: Bool
    let isSeries: Bool
    let persianSubtitle: Bool
    let comingSoon: Bool
    let year: Int?
    let yearEnd: Int?
    let age: String?
    let minutes: Int?
    let english: String
    let local: String?
    let plotLocal: String?
    let plotEnglish: String?
    let genres: [String]
    let cast: [Person]
    let directors: [Person]
    let posterMedium: URL?
    let posterLarge: URL?
    let cover: URL?
    let imdb: Double?
    let nama30: Double?
    let nextEpisodeCaption: String?
    let nextEpisodeDate: String?
    /// continue_watching entries only
    let episodeTitle: String?
    let progress: Double

    init?(_ j: J) {
        guard let id = j["id"].int else { return nil }
        self.id = id
        titleType = j["options"]["title_type"].string ?? "movie"
        canStream = j["options"]["stream"].bool ?? false
        isSeries = j["options"]["is_series"].bool ?? false
        persianSubtitle = j["options"]["persian_subtitle"].bool ?? false
        comingSoon = j["options"]["coming_soon"].bool ?? false
        year = j["info"]["year"].int
        yearEnd = j["info"]["year_end"].int
        age = j["info"]["age"].string
        minutes = j["info"]["time"]["default"].int
        english = j["title"]["english"].string ?? ""
        local = j["title"]["local"].string
        plotLocal = j["plot"]["local"].string
        plotEnglish = j["plot"]["english"].string
        genres = j["genre"].array.compactMap { $0["name"].string ?? $0.string }
        func people(_ list: J) -> [Person] {
            list.array.compactMap { p in p["name"].string.map { Person(name: $0, imdb: p["imdb"].string) } }
        }
        cast = people(j["cast"])
        directors = people(j["crew"]["director"])
        let poster = j["image"]["poster"]
        func pick(_ size: String) -> URL? { poster["jpg"][size].url ?? poster["webp"][size].url }
        posterMedium = pick("medium") ?? pick("large") ?? pick("small")
        posterLarge = pick("large") ?? pick("medium") ?? pick("big")
        cover = j["image"]["cover"]["jpg"].url ?? j["image"]["cover"]["webp"].url
        imdb = j["score"]["imdb"]["score"].double
        nama30 = j["score"]["30nama"]["score"].double
        nextEpisodeCaption = j["air"]["next_episode_caption"].string
        nextEpisodeDate = j["air"]["next_episode_date"]["j"].string
        episodeTitle = j["data"]["episode_title"].string
        progress = j["data"]["progress"].double ?? 0
    }

    var name: String {
        if let l = local?.trimmed, !l.isEmpty { return l }
        return english
    }

    var plot: String? {
        if let p = plotLocal?.trimmed, !p.isEmpty { return p }
        return plotEnglish
    }
}

struct Page {
    let posts: [Title]
    let pages: Int?

    init(_ j: J) {
        posts = j["posts"].array.compactMap { Title($0) }
        pages = j["pages"].int
    }
}

struct HomeStream {
    let hero: [Title]
    let suggested: [Title]
    let movies: [Title]
    let series: [Title]
    let anime: [Title]

    init(_ j: J) {
        hero = Page(j["hero_header"]).posts
        suggested = Page(j["suggested"]).posts
        movies = Page(j["movies"]).posts
        series = Page(j["series"]).posts
        anime = Page(j["anime"]).posts
    }
}

struct MenuItem: Identifiable {
    let id: Int
    let name: String
    let slug: String
    let thumb: URL?

    init?(_ j: J) {
        guard let slug = j["slug"].string else { return nil }
        self.slug = slug
        id = j["id"].int ?? slug.hashValue
        name = j["name"].string ?? slug
        thumb = j["image"]["jpg"]["thumb"].url ?? j["image"]["webp"]["thumb"].url
    }
}

struct MenuData {
    let genres: [MenuItem]
    let categories: [MenuItem]
    init(_ j: J) {
        genres = j["genres"].array.compactMap { MenuItem($0) }
        categories = j["categories"].array.compactMap { MenuItem($0) }
    }
}

struct User {
    let id: Int
    let name: String
    let type: String
    let allowedToStream: Bool
    let avatar: URL?
    let daysLeft: Int?
    let expiresOn: String?

    init(_ j: J) {
        id = j["user_id"].int ?? 0
        name = j["user_name"].string ?? ""
        type = j["user_type"].string ?? ""
        allowedToStream = j["user_allowed_to_stream"].bool ?? true
        avatar = j["user_avatar"].url
        daysLeft = j["user_expire"]["days"].int
        expiresOn = j["user_expire"]["j"].string?.split(separator: " ").first.map(String.init)
    }
}

struct QrCode {
    let code: String
    let url: String
}

struct StreamSource {
    let label: String
    let url: URL
}

struct StreamItem: Identifiable {
    var id: Int { fileId }
    let fileId: Int
    let season: Int?
    let episode: String?
    let episodeNumber: Int?
    let episodeName: String?
    let sources: [StreamSource]
    let subtitleFa: URL?
    let subtitleEn: URL?
    let introStart: Double?
    let introEnd: Double?
    let creditsAt: Double?
    let token: String

    init?(_ j: J) {
        guard let fileId = j["info"]["file_id"].int else { return nil }
        self.fileId = fileId
        season = j["info"]["season"].int
        episode = j["info"]["episode"].string
        episodeNumber = j["info"]["episode_number"].int
        episodeName = j["info"]["episode_name"].string
        sources = j["file"]["m3u8"].array.compactMap { s in
            s["default"].url.map { StreamSource(label: s["label"].string ?? "", url: $0) }
        }
        subtitleFa = j["file"]["subtitle"]["fa"].url
        subtitleEn = j["file"]["subtitle"]["en"].url
        introStart = hms(j["options"]["intro_start"].string)
        introEnd = hms(j["options"]["intro_end"].string)
        creditsAt = hms(j["options"]["end"].string)
        token = j["options"]["token"].string ?? ""
    }

    /// "قسمت ۳" style number, falling back to the raw episode string.
    var episodeLabel: String {
        if let n = episodeNumber { return "\(n)" }
        return episode ?? ""
    }
}

struct StreamResume {
    let fileId: Int
    let time: Double
    let season: Int?
    let episodeName: String?
}

struct StreamInfo {
    let name: String
    let resume: StreamResume?
    let items: [StreamItem]

    init(_ j: J) {
        let local = j["info"]["title"]["local"].string?.trimmed
        name = (local?.isEmpty == false ? local : nil) ?? j["info"]["title"]["english"].string ?? ""
        let r = j["continue_watching"]
        if let fileId = r["file_id"].int {
            resume = StreamResume(
                fileId: fileId,
                time: r["time"].double ?? 0,
                season: r["season"].int,
                episodeName: r["episode_name"].string
            )
        } else {
            resume = nil
        }
        items = j["hls"].array.compactMap { StreamItem($0) }
    }
}

struct AppNotification: Identifiable {
    let id: Int
    let title: String
    let text: String
    let date: String
    let read: Bool
    let postId: Int?

    init?(_ j: J) {
        guard let id = j["id"].int else { return nil }
        self.id = id
        title = j["title"].string ?? ""
        text = Self.plain(j["text"].string ?? j["message"].string ?? j["content"].string ?? "")
        date = j["date"].string ?? j["date"]["j"].string ?? j["date"]["g"].string ?? ""
        read = j["read"].bool ?? false
        postId = j["post_id"].int
    }

    /// The server sends light HTML (`<small>`, `<br>`); the TV shows plain text.
    private static func plain(_ html: String) -> String {
        html.replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct Option: Identifiable {
    let name: String
    let value: String
    var id: String { value }
}

struct AdvancedParameters {
    let genre: [Option]
    let type: [Option]
    let imdbRate: [Option]
    let country: [Option]

    init(_ j: J) {
        func options(_ list: J) -> [Option] {
            list.array.compactMap { o in
                guard let name = o["name"].string, let value = o["value"].string else { return nil }
                return Option(name: name, value: value)
            }
        }
        genre = options(j["genre"])
        type = options(j["type"])
        imdbRate = options(j["imdb_rate"])
        country = options(j["country"])
    }
}

struct MyLists {
    var watchlist: Set<Int> = []
    var favorite: Set<Int> = []

    init() {}
    init(_ j: J) {
        watchlist = Set(j["watchlist"]["post"].array.compactMap { $0.int })
        favorite = Set(j["favorite"]["post"].array.compactMap { $0.int })
    }

    func contains(_ group: String, _ id: Int) -> Bool {
        group == "watchlist" ? watchlist.contains(id) : favorite.contains(id)
    }

    mutating func set(_ group: String, _ id: Int, _ on: Bool) {
        if group == "watchlist" {
            if on { watchlist.insert(id) } else { watchlist.remove(id) }
        } else {
            if on { favorite.insert(id) } else { favorite.remove(id) }
        }
    }
}

/// "00:01:30" → 90
func hms(_ s: String?) -> Double? {
    guard let s = s?.trimmed, !s.isEmpty else { return nil }
    let parts = s.split(separator: ":").map { Double($0) }
    if parts.isEmpty || parts.contains(where: { $0 == nil }) { return nil }
    return parts.reduce(0) { $0 * 60 + ($1 ?? 0) }
}

/// "1:02:03" / "02:03"
func clock(_ s: Double) -> String {
    guard s.isFinite else { return "--:--" }
    let total = Int(s)
    let h = total / 3600, m = (total % 3600) / 60, sec = total % 60
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%02d:%02d", m, sec)
}
