import Foundation

/// English names for the server's Persian category, genre, type and country lists, and for the
/// templated texts it sends (notifications, episode names). Only used when the app is in English.
enum Catalog {
    /// Persian genre name -> English. Titles list their genres by Persian name.
    private static let genreByName: [String: String] = [
        "درام": "Drama",
        "کمدی": "Comedy",
        "هیجان انگیز": "Thriller",
        "عاشقانه": "Romance",
        "مستند": "Documentary",
        "اکشن": "Action",
        "جنایی": "Crime",
        "ترسناک": "Horror",
        "ماجراجویی": "Adventure",
        "معمایی": "Mystery",
        "خانوادگی": "Family",
        "فانتزی": "Fantasy",
        "علمی تخیلی": "Sci-Fi",
        "انیمیشن": "Animation",
        "تاریخی": "History",
        "زندگی‌نامه": "Biography",
        "کوتاه": "Short",
        "موزیک": "Music",
        "جنگ": "War",
        "ئالیتی شو": "Reality TV",
        "ورزشی": "Sport",
        "موزیکال": "Musical",
        "وسترن": "Western",
        "استند آپ کمدی": "Stand-Up Comedy",
        "مسابقه تلویزیونی": "Game Show",
        "نوآر": "Film Noir",
        "تاک شو": "Talk Show",
        "خبری": "News",
        "آشپزی": "Cooking",
        "آموزشی": "Educational",
        "ابرقهرمانی": "Superhero",
        "تئاتر": "Theatre",
        "جادو": "Magic",
        "سیتکام": "Sitcom",
        "لایواکشن": "Live-Action",
        "ووشیا": "Wuxia",
        "اپرا، باله": "Opera & Ballet"
    ]

    private static let categories: [String: String] = [
        "movies": "Movies", "series": "Series", "anime": "Anime", "miniseries": "Miniseries",
        "suggested": "Suggested", "concert": "Concerts", "coming-soon": "Coming Soon",
        "ceremony": "Ceremonies", "new-releases": "New Releases",
    ]

    private static let types: [String: String] = [
        "movie": "Movie", "series": "Series", "miniseries": "Miniseries", "anime": "Anime",
        "movie_anime": "Anime Movie", "series_anime": "Anime Series", "animation": "Animation",
        "documentary": "Documentary", "ceremony": "Ceremony", "concert": "Concert",
    ]

    /// Codes the system's region list does not know.
    private static let oldCountries: [String: String] = [
        "XWG": "West Germany", "SUHH": "Soviet Union", "CSHH": "Czechoslovakia", "XYU": "Yugoslavia",
        "DDDE": "East Germany", "HK": "Hong Kong", "PS": "Palestine", "CN": "China",
    ]

    static func genre(_ fa: String) -> String { Lang.current == .en ? (genreByName[fa] ?? fa) : fa }

    /// Menu categories and genres, by slug.
    static func menu(slug: String, name: String) -> String {
        guard Lang.current == .en else { return name }
        if let c = categories[slug] { return c }
        if let g = genreByName[name] { return g }
        return name
    }

    static func option(kind: Option.Kind, value: String, name: String) -> String {
        guard Lang.current == .en else { return name }
        switch kind {
        case .genre: return genreByName[name] ?? name
        case .type: return types[value] ?? name
        case .country:
            if let o = oldCountries[value] { return o }
            return Locale(identifier: "en").localizedString(forRegionCode: value) ?? name
        case .rate:
            guard let v = Double(value) else { return name }
            return v < 0 ? "Below \(String(format: "%.1f", -v))" : "Above \(String(format: "%.1f", v))"
        }
    }
}

/// Server texts that follow fixed Persian templates (episode names, notifications).
enum ServerText {
    static func english(_ s: String) -> String {
        guard Lang.current == .en else { return s }
        var t = latinDigits(s).replacingOccurrences(of: "\r\n", with: "\n")
        for (pattern, template) in rules {
            t = t.replacingOccurrences(of: pattern, with: template, options: .regularExpression)
        }
        return t.replacingOccurrences(of: " {2,}", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\n ", with: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static let rules: [(String, String)] = [
        ("فصل (\\d+) - قسمت (\\d+)", "Season $1 · Episode $2"),
        ("امکان تماشای آنلاین قسمت جدید سریال (.+?) فراهم شد", "A new episode of $1 can now be streamed"),
        ("قسمت جدید سریال (.+?) به پخش آنلاین اضافه شد", "New episode of $1 added to online streaming"),
        ("قسمت جدید سریال (.+?) اضافه شد", "New episode of $1 added"),
        ("زیرنویس فارسی (.+?) اضافه شد", "Persian subtitles for $1 added"),
        ("(?:فیلم|انیمه|سریال|انیمیشن) (.+?) به پخش آنلاین اضافه شد", "$1 added to online streaming"),
        ("(?:فیلم|انیمه|سریال|انیمیشن) (.+?) اضافه شد", "$1 added"),
        ("توضیحات بیشتر:", "More details:"),
        ("و اپیزود (\\d+) از فصل (\\d+)", "and episode $1 of season $2"),
        ("اپیزودهای (\\d+) تا (\\d+) فصل (\\d+)", "Episodes $1–$2, season $3"),
        ("اپیزود (\\d+) تا (\\d+) فصل (\\d+)", "Episodes $1–$2, season $3"),
        ("اپیزود (\\d+) و (\\d+) فصل (\\d+)", "Episodes $1 and $2, season $3"),
        ("اپیزود (\\d+) (?:از )?فصل (\\d+)", "Episode $1, season $2"),
        ("(?:به نام|با عنوان)", "titled"),
    ]

    private static func latinDigits(_ s: String) -> String {
        let fa = Array("۰۱۲۳۴۵۶۷۸۹"), ar = Array("٠١٢٣٤٥٦٧٨٩")
        return String(s.map { c in
            if let i = fa.firstIndex(of: c) ?? ar.firstIndex(of: c) { return Character("\(i)") }
            return c
        })
    }

    /// "1405-09-30" (Persian calendar) -> "Dec 21, 2026"; unchanged in Persian.
    static func jalaliDay(_ s: String) -> String {
        guard Lang.current == .en else { return s }
        let p = latinDigits(s).split(whereSeparator: { $0 == "-" || $0 == "/" }).compactMap { Int($0) }
        guard p.count == 3 else { return s }
        var calendar = Calendar(identifier: .persian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        guard let date = calendar.date(from: DateComponents(year: p[0], month: p[1], day: p[2], hour: 12)) else { return s }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: date)
    }

    private static let months = ["فروردین", "اردیبهشت", "خرداد", "تیر", "مرداد", "شهریور", "مهر", "آبان", "آذر", "دی", "بهمن", "اسفند"]

    /// "۱۷ مهر ۱۴۰۵ جمعه" -> "Oct 9, 2026".
    static func date(_ s: String) -> String {
        guard Lang.current == .en else { return s }
        let parts = latinDigits(s).split(separator: " ").map(String.init)
        guard parts.count >= 3, let day = Int(parts[0]), let month = months.firstIndex(of: parts[1]), let year = Int(parts[2]) else { return s }
        var calendar = Calendar(identifier: .persian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        guard let date = calendar.date(from: DateComponents(year: year, month: month + 1, day: day, hour: 12)) else { return s }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en")
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: date)
    }
}
