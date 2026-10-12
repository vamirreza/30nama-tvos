import SwiftUI

// Only these two orders change the result on v2; "imdb" and "date" fall back to relevance.
private enum Order: String { case relevant, year }

struct ListView: View {
    let route: ListRoute
    @State private var order = Order.relevant

    private func fetcher(_ order: Order) -> (Int) async throws -> Page {
        switch route.source {
        case .archive(let slug):
            return { page in try await API.archive(slug, page: page, orderBy: order.rawValue) }
        case .filter(let json):
            return { page in try await API.advancedSearch(json, page: page, orderBy: order.rawValue) }
        case .person(let role, let name, let imdb):
            let params: [String: Any] = [role: imdb ?? name, "stream": "true"]
            let json = (try? JSONSerialization.data(withJSONObject: params, options: [.sortedKeys]))
                .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
            return { page in try await API.advancedSearch(json, page: page, orderBy: order.rawValue) }
        }
    }

    private var kicker: String? {
        if case .person(let role, _, _) = route.source { return role == "actor" ? tr("آثار بازیگر") : tr("آثار کارگردان") }
        return nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.sectionGap) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        if let kicker { Text(kicker).font(.appCallout).foregroundStyle(Theme.textDim) }
                        PageTitle(text: route.title)
                    }
                    Spacer()
                    HStack(spacing: 20) {
                        ChipButton(label: tr("مرتبط‌ترین"), on: order == .relevant) { order = .relevant }
                        ChipButton(label: tr("جدیدترین"), on: order == .year) { order = .year }
                    }
                }
                .tvFocusSection()
                PagedGrid(fetch: fetcher(order)).id(order.rawValue)
            }
            .padding(.horizontal, Metrics.pagePad)
            .padding(.vertical, Metrics.pageVPad)
        }
        .appBackground()
    }
}

// MARK: - Search

/// Results refresh as the viewer types, which stands in for autocomplete.
struct SearchView: View {
    @EnvironmentObject private var router: Router
    @State private var text = ""
    @State private var query = ""
    private let minChars = 3   // the server answers shorter queries with "search cannot be empty"

    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                if query.count >= minChars {
                    PagedGrid(empty: tr("نتیجه‌ای برای «%@» پیدا نشد", query)) { page in try await API.search(query, page: page) }
                        .id(query)
                } else {
                    EmptyState(icon: "magnifyingglass", text: tr("دست‌کم سه حرف بنویسید."))
                }
            }
            .padding(.horizontal, Metrics.pagePad)
        }
        .appBackground()
        .searchable(text: $text, prompt: tr("نام فیلم، سریال یا انیمه"))
        .task(id: text) {
            try? await Task.sleep(nanoseconds: 450_000_000)
            if !Task.isCancelled { query = text.trimmed }
        }
    }
}

// MARK: - Browse

struct BrowseView: View {
    @State private var menu: MenuData?
    @State private var error: String?
    // Categories that never stream are left out; this app only plays.
    private let hidden = ["coming-soon"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.sectionGap) {
                HStack {
                    PageTitle(text: tr("دسته‌بندی‌ها"))
                    Spacer()
                    NavigationLink(value: Route.filters) { Label(tr("جستجوی پیشرفته"), systemImage: "slider.horizontal.3") }
                        .buttonStyle(.pillProminent)
                }
                .tvFocusSection()
                if let m = menu {
                    tiles(tr("نوع"), m.categories.filter { !hidden.contains($0.slug) })
                    tiles(tr("ژانر"), m.genres)
                } else if let error {
                    ErrorNote(message: error) { Task { await load() } }
                } else {
                    ProgressView().tint(.white).frame(maxWidth: .infinity).padding(Metrics.pagePad)
                }
            }
            .padding(.horizontal, Metrics.pagePad)
            .padding(.vertical, Metrics.pageVPad)
        }
        .appBackground()
        .task { if menu == nil { await load() } }
    }

    private func load() async {
        do {
            error = nil
            menu = try await API.menu()
        } catch {
            self.error = describe(error)
        }
    }

    private func tiles(_ title: String, _ items: [MenuItem]) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            SectionHeader(title: title)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: Metrics.tileMin, maximum: Metrics.tileMax), spacing: Metrics.gridGap)], spacing: Metrics.gridGap) {
                ForEach(items) { m in
                    NavigationLink(value: Route.list(ListRoute(title: m.name, source: .archive(slug: m.slug)))) {
                        ZStack(alignment: .bottomLeading) {
                            RemoteImage(url: m.thumb, maxPixel: 640) {
                                LinearGradient(colors: [Theme.redDeep.opacity(0.7), Theme.card], startPoint: .topLeading, endPoint: .bottomTrailing)
                            }
                            .frame(width: Metrics.tileWidth, height: Metrics.tileHeight)
                            .clipped()
                            LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .center, endPoint: .bottom)
                            Text(m.name).font(.appTitle3Bold).shadow(color: .black.opacity(0.6), radius: 4).padding(16)
                        }
                        .frame(width: Metrics.tileWidth, height: Metrics.tileHeight)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
                        .focusShape(cornerRadius: Theme.radius)
                        .floatOnFocus()
                    }
                    .tileButtonStyle()
                }
            }
        }
        .tvFocusSection()
    }
}

// MARK: - Filters

struct FiltersView: View {
    private struct Decade { let label: String; let min: Int; let max: Int }
    private let decades = [
        Decade(label: tr("دهه ۲۰۲۰"), min: 2020, max: 2029),
        Decade(label: tr("دهه ۲۰۱۰"), min: 2010, max: 2019),
        Decade(label: tr("دهه ۲۰۰۰"), min: 2000, max: 2009),
        Decade(label: tr("دهه ۱۹۹۰"), min: 1990, max: 1999),
        Decade(label: tr("قدیمی‌تر"), min: 1890, max: 1989),
    ]
    // The parameter list is long (87 countries); the TV shows the most useful slice of each.
    private let countryCount = 16
    private let rateCount = 6

    @State private var params: AdvancedParameters?
    @State private var error: String?
    @State private var types: Set<String> = []
    @State private var genres: Set<String> = []
    @State private var countries: Set<String> = []
    @State private var rate: String?
    @State private var decade: Int?

    private var resultsRoute: Route {
        // Only streamable titles: the TV app cannot download.
        var p: [String: Any] = ["stream": "true"]
        if !types.isEmpty { p["type"] = types.sorted() }
        if !genres.isEmpty { p["genre"] = genres.sorted() }
        if !countries.isEmpty { p["country"] = countries.sorted() }
        if let rate, let r = Double(rate) { p["imdb_rate"] = r }
        if let d = decades.first(where: { $0.min == decade }) {
            p["min_year"] = d.min
            p["max_year"] = d.max
        }
        let json = (try? JSONSerialization.data(withJSONObject: p, options: [.sortedKeys]))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        return .list(ListRoute(title: tr("نتایج جستجوی پیشرفته"), source: .filter(json: json)))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.sectionGap) {
                HStack {
                    PageTitle(text: tr("جستجوی پیشرفته"))
                    Spacer()
                    HStack(spacing: 20) {
                        NavigationLink(value: resultsRoute) { Label(tr("نمایش نتایج"), systemImage: "magnifyingglass") }
                            .buttonStyle(.pillProminent)
                        Button(tr("پاک کردن")) {
                            types = []; genres = []; countries = []; rate = nil; decade = nil
                        }
                        .buttonStyle(.pill)
                    }
                }
                .tvFocusSection()
                if let p = params {
                    group(tr("نوع"), p.type, selected: { types.contains($0) }) { toggle(&types, $0) }
                    group(tr("ژانر"), p.genre, selected: { genres.contains($0) }) { toggle(&genres, $0) }
                    group(tr("امتیاز IMDb"), Array(p.imdbRate.prefix(rateCount)), selected: { rate == $0 }) { rate = rate == $0 ? nil : $0 }
                    group(tr("سال ساخت"), decades.map { Option(name: $0.label, value: "\($0.min)") }, selected: { decade == Int($0) }) {
                        decade = decade == Int($0) ? nil : Int($0)
                    }
                    group(tr("کشور"), Array(p.country.prefix(countryCount)), selected: { countries.contains($0) }) { toggle(&countries, $0) }
                } else if let error {
                    ErrorNote(message: error) { Task { await load() } }
                } else {
                    ProgressView().tint(.white).frame(maxWidth: .infinity).padding(Metrics.pagePad)
                }
            }
            .padding(.horizontal, Metrics.pagePad)
            .padding(.vertical, Metrics.pageVPad)
        }
        .appBackground()
        .task { if params == nil { await load() } }
    }

    private func load() async {
        do {
            error = nil
            params = try await API.advancedSearchParameters()
        } catch {
            self.error = describe(error)
        }
    }

    private func toggle(_ set: inout Set<String>, _ v: String) {
        if set.contains(v) { set.remove(v) } else { set.insert(v) }
    }

    private func group(_ title: String, _ options: [Option], selected: @escaping (String) -> Bool, pick: @escaping (String) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: title)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: Metrics.chipMin), spacing: 20)], alignment: .leading, spacing: 20) {
                ForEach(options) { o in
                    ChipButton(label: o.name, on: selected(o.value)) { pick(o.value) }
                }
            }
        }
        .tvFocusSection()
    }
}
