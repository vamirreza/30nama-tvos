import SwiftUI

// MARK: - Navigation

enum ListSource: Hashable {
    case archive(slug: String)
    /// `json` is the advanced_search `parameters` object, already encoded.
    case filter(json: String)
    /// `imdb` (nm…) matches exactly; a name alone matches any credit containing one of its words.
    case person(role: String, name: String, imdb: String?)
}

struct ListRoute: Hashable {
    let title: String
    let source: ListSource
}

enum Route: Hashable {
    case title(Int)
    case list(ListRoute)
    case filters
    case notifications
}

@ViewBuilder
func destination(for route: Route) -> some View {
    switch route {
    case .title(let id): TitleView(id: id)
    case .list(let r): ListView(route: r)
    case .filters: FiltersView()
    case .notifications: NotificationsView()
    }
}

/// Every tab sits in its own stack so Back returns to the same spot.
struct Nav<Content: View>: View {
    private let content: () -> Content
    init(@ViewBuilder content: @escaping () -> Content) { self.content = content }

    var body: some View {
        NavigationStack {
            content().navigationDestination(for: Route.self) { destination(for: $0) }
        }
    }
}

// MARK: - Posters

struct PosterCell: View {
    let title: Title
    var width: CGFloat = Metrics.posterWidth
    /// nil opens the title page.
    var onSelect: (() -> Void)?

    private var poster: some View {
        RemoteImage(url: title.posterMedium, maxPixel: 520) {
            ZStack {
                Theme.card
                LogoMark(height: width * 0.3).opacity(0.25)
            }
        }
        .frame(width: width, height: width * 1.5)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).strokeBorder(Theme.stroke, lineWidth: 1))
        .focusShape(cornerRadius: Theme.radius)
        .overlay(alignment: .bottom) {
            if title.progress > 0 {
                ProgressView(value: min(1, title.progress / 100))
                    .tint(Theme.red)
                    .padding(.horizontal, 12).padding(.bottom, 12).padding(.top, 30)
                    .background(LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .top, endPoint: .bottom))
            }
        }
        .overlay(alignment: .topLeading) {
            if title.persianSubtitle {
                Image(systemName: "captions.bubble.fill")
                    .font(.appCaption2Bold)
                    .padding(8)
                    .background(.black.opacity(0.65), in: Circle())
                    .padding(8)
            }
        }
    }

    private var caption: some View {
        VStack(spacing: 4) {
            Text(title.name).font(.appCalloutMedium).lineLimit(1)
            if let sub = title.episodeTitle {
                Text(sub).font(.appCaption).foregroundStyle(Theme.textDim).lineLimit(1)
            } else if title.imdb != nil || title.year != nil {
                HStack(spacing: 6) {
                    if let s = title.imdb {
                        Image(systemName: "star.fill").foregroundStyle(Theme.gold)
                        Text(String(format: "%.1f", s))
                    }
                    if let y = title.year { Text("\(y)") }
                }
                .font(.appCaption)
                .foregroundStyle(Theme.textDim)
            }
        }
        .frame(width: width)
    }

    var body: some View {
        VStack(spacing: 14) {
            if let onSelect {
                Button(action: onSelect) { poster }.posterButtonStyle()
            } else {
                NavigationLink(value: Route.title(title.id)) { poster }.posterButtonStyle()
            }
            caption
        }
        .frame(width: width)
    }
}

struct TitleRow: View {
    let title: String
    let items: [Title]
    var onSelect: ((Title) -> Void)?

    private func action(for t: Title) -> (() -> Void)? {
        guard let onSelect else { return nil }
        return { onSelect(t) }
    }

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                SectionHeader(title: title).padding(.horizontal, Metrics.pagePad)
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: Metrics.rowGap) {
                        ForEach(Array(items.enumerated()), id: \.offset) { _, t in
                            PosterCell(title: t, onSelect: action(for: t))
                        }
                    }
                    .padding(.horizontal, Metrics.pagePad)
                    .padding(.vertical, Metrics.rowVPad)
                }
                .rowClipDisabled()
            }
        }
    }
}

// MARK: - Paged grid

@MainActor
final class PagedLoader: ObservableObject {
    @Published private(set) var items: [Title] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?
    @Published private(set) var finished = false

    private var page = 0
    private let fetch: (Int) async throws -> Page

    init(fetch: @escaping (Int) async throws -> Page) { self.fetch = fetch }

    func loadMore() async {
        guard !isLoading, !finished else { return }
        isLoading = true
        error = nil
        do {
            let p = try await fetch(page + 1)
            page += 1
            items += p.posts
            // Another page only when the server says there is one.
            finished = p.posts.isEmpty || (p.pages.map { page >= $0 } ?? true)
        } catch {
            self.error = describe(error)
        }
        isLoading = false
    }
}

/// A paged poster grid. The next page loads when focus nears the last row.
struct PagedGrid: View {
    @StateObject private var loader: PagedLoader
    private let empty: String
    private let onSelect: ((Title) -> Void)?
    private let columns = [GridItem(.adaptive(minimum: Metrics.gridMin, maximum: Metrics.gridMax), spacing: Metrics.gridGap)]

    init(empty: String = "چیزی پیدا نشد", onSelect: ((Title) -> Void)? = nil, fetch: @escaping (Int) async throws -> Page) {
        _loader = StateObject(wrappedValue: PagedLoader(fetch: fetch))
        self.empty = empty
        self.onSelect = onSelect
    }

    private func cell(_ index: Int, _ t: Title) -> some View {
        let action: (() -> Void)? = onSelect == nil ? nil : { onSelect?(t) }
        return PosterCell(title: t, onSelect: action)
            .onAppear {
                if index >= loader.items.count - 8 { Task { await loader.loadMore() } }
            }
    }

    var body: some View {
        VStack(spacing: 30) {
            LazyVGrid(columns: columns, spacing: Metrics.gridRowGap) {
                ForEach(Array(loader.items.enumerated()), id: \.offset) { i, t in cell(i, t) }
            }
            if loader.isLoading { ProgressView().tint(.white).padding(40) }
            if let e = loader.error { Text(e).foregroundStyle(Theme.red) }
            if loader.items.isEmpty && !loader.isLoading && loader.error == nil && loader.finished {
                EmptyState(icon: "film.stack", text: empty)
            }
        }
        .task { if loader.items.isEmpty { await loader.loadMore() } }
    }
}

// MARK: - Bits

struct MetaLine: View {
    let parts: [String]
    var body: some View {
        Text(parts.filter { !$0.isEmpty }.joined(separator: "  ·  "))
            .font(.appCallout)
            .foregroundStyle(Theme.textDim)
    }
}

/// A large page heading with the red accent bar.
struct PageTitle: View {
    let text: String
    var body: some View {
        HStack(spacing: 18) {
            Capsule().fill(Theme.red).frame(width: Metrics.accentWidth, height: Metrics.accentHeight * 1.4)
            Text(text).font(.appLargeTitle)
        }
    }
}

struct EmptyState: View {
    let icon: String
    let text: String
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: icon).font(.system(size: Metrics.emptyIcon)).foregroundStyle(Theme.red.opacity(0.8))
            Text(text).font(.appBody).foregroundStyle(Theme.textDim).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(Metrics.pagePad)
    }
}

struct ErrorNote: View {
    let message: String
    var retry: (() -> Void)?
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: Metrics.emptyIcon)).foregroundStyle(Theme.red)
            Text(message).font(.appBody).multilineTextAlignment(.center)
            if let retry { Button("تلاش دوباره", action: retry).buttonStyle(.pillProminent) }
        }
        .frame(maxWidth: .infinity)
        .padding(Metrics.pagePad)
    }
}

/// Splash and loading state: the logo over the brand background.
struct LaunchView: View {
    var body: some View {
        VStack(spacing: 40) {
            Logo(height: Metrics.launchLogo)
            ProgressView().tint(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appBackground()
    }
}

/// Chip that shows a check while on; used for filters, tabs and settings.
struct ChipButton: View {
    let label: String
    var on: Bool = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            if on { Label(label, systemImage: "checkmark") } else { Text(label) }
        }
        .buttonStyle(ChipButtonStyle(on: on))
    }
}
