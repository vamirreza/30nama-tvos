import SwiftUI

// MARK: - My list

struct MyListView: View {
    @EnvironmentObject private var router: Router
    private enum Tab: String, CaseIterable, Identifiable {
        case watchlist, favorite, continueWatching
        var id: String { rawValue }
        var label: String {
            switch self {
            case .watchlist: return "لیست تماشا"
            case .favorite: return "علاقه‌مندی‌ها"
            case .continueWatching: return "ادامه تماشا"
            }
        }
        var empty: String {
            switch self {
            case .watchlist: return "لیست تماشا خالی است. در صفحه هر فیلم «+ لیست تماشا» را بزنید."
            case .favorite: return "هنوز چیزی به علاقه‌مندی‌ها اضافه نکرده‌اید."
            case .continueWatching: return "چیزی در حال تماشا نیست."
            }
        }
    }

    @State private var tab = Tab.watchlist
    @State private var reload = 0
    @State private var picked: Title?
    @State private var detail: Int?

    private func fetch(_ tab: Tab) -> (Int) async throws -> Page {
        switch tab {
        case .continueWatching: return { _ in try await API.continueWatching() }
        case .watchlist: return { page in try await API.list("watchlist", page: page) }
        case .favorite: return { page in try await API.list("favorite", page: page) }
        }
    }

    // Continue-watching entries open a play/details/remove sheet; the other lists open the title.
    private var selectHandler: ((Title) -> Void)? {
        guard tab == .continueWatching else { return nil }
        return { t in picked = t }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                PageTitle(text: "لیست من")
                ChoiceRow(options: Tab.allCases, selection: tab, label: { $0.label }) { tab = $0 }
                    .tvFocusSection()

                PagedGrid(empty: tab.empty, onSelect: selectHandler, fetch: fetch(tab))
                .id("\(tab.rawValue)-\(reload)")
            }
            .padding(.horizontal, Metrics.pagePad)
            .padding(.vertical, Metrics.pageVPad)
        }
        .appBackground()
        .navigationDestination(item: $detail) { TitleView(id: $0) }
        .confirmationDialog(
            picked.map { $0.name + ($0.episodeTitle.map { " · \($0)" } ?? "") } ?? "",
            isPresented: Binding(get: { picked != nil }, set: { if !$0 { picked = nil } }),
            titleVisibility: .visible
        ) {
            if let t = picked {
                Button { router.play(t.id) } label: { Label("ادامه پخش", systemImage: "play.fill") }
                Button("جزئیات") { detail = t.id }
                Button("حذف از ادامه تماشا", role: .destructive) {
                    Task {
                        try? await API.dismissContinue(t.id)
                        reload += 1
                    }
                }
            }
        }
    }
}

// MARK: - Notifications

struct NotificationsView: View {
    @State private var items: [AppNotification] = []
    @State private var loaded = false
    @State private var error: String?
    @State private var detail: Int?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.itemSpacing) {
                PageTitle(text: "اعلان‌ها").padding(.bottom, Metrics.itemSpacing)
                if let error { Text(error).foregroundStyle(Theme.red) }
                if loaded && items.isEmpty { EmptyState(icon: "bell.slash", text: "اعلان تازه‌ای ندارید.") }
                if !loaded && error == nil { ProgressView().tint(.white).frame(maxWidth: .infinity).padding(60) }
                ForEach(items) { n in
                    Button { open(n) } label: {
                        HStack(alignment: .top, spacing: 16) {
                            Circle()
                                .fill(n.read ? Color.clear : Theme.red)
                                .frame(width: 12, height: 12)
                                .padding(.top, 10)
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(n.title).font(.appHeadline)
                                    Spacer()
                                    Text(n.date).font(.appCaption).foregroundStyle(Theme.textDim)
                                }
                                if !n.text.isEmpty { Text(n.text).font(.appCallout).foregroundStyle(Theme.textDim) }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(Metrics.cardPad)
                        .background(Theme.card)
                    }
                    .buttonStyle(PosterButtonStyle(radius: Theme.radius * 0.8))
                    .opacity(n.read ? 0.75 : 1)
                }
            }
            .padding(.horizontal, Metrics.pagePad)
            .padding(.vertical, Metrics.pageVPad)
        }
        .appBackground()
        .navigationDestination(item: $detail) { TitleView(id: $0) }
        .task { await load() }
    }

    private func load() async {
        do {
            error = nil
            items = try await API.notifications()
            loaded = true
        } catch {
            self.error = describe(error)
        }
    }

    private func open(_ n: AppNotification) {
        if !n.read {
            Task {
                try? await API.readNotification(n.id)
                await load()
            }
        }
        if let post = n.postId { detail = post }
    }
}

// MARK: - Profile

struct ProfileView: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var settings: SettingsStore
    @State private var confirmLogout = false

    private let plans = ["golden": "طلایی", "silver": "نقره‌ای", "bronze": "برنزی", "free": "رایگان"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.sectionGap) {
                PageTitle(text: "حساب و تنظیمات")
                if let u = app.user { account(u) }

                setting("زیرنویس پیش‌فرض", icon: "captions.bubble", options: SubLang.allCases, selection: settings.subLang, label: { $0.label }) { settings.subLang = $0 }
                setting("اندازه زیرنویس", icon: "textformat.size", options: SubSize.allCases, selection: settings.subSize, label: { $0.label }) { settings.subSize = $0 }
                setting("صدا", icon: "speaker.wave.2", options: AudioPref.allCases, selection: settings.audio, label: { $0.label }) { settings.audio = $0 }
                setting("کیفیت تصویر", icon: "sparkles.tv", options: Quality.allCases, selection: settings.quality, label: { $0.label }) { settings.quality = $0 }

                #if os(iOS)
                NavigationLink(value: Route.notifications) {
                    Label("اعلان‌ها", systemImage: "bell").frame(maxWidth: .infinity)
                }
                .buttonStyle(.pill)
                #endif

                HStack {
                    Button { confirmLogout = true } label: { Label("خروج از حساب", systemImage: "rectangle.portrait.and.arrow.right") }
                        .buttonStyle(.pill)
                    Spacer()
                }

                VStack(spacing: 10) {
                    Logo(height: Metrics.launchLogo * 0.6).opacity(0.7)
                    Text("برنامهٔ غیررسمی سی‌نما").font(.appCaption).foregroundStyle(Theme.textDim)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, Metrics.sectionGap)
            }
            .padding(.horizontal, Metrics.pagePad)
            .padding(.vertical, Metrics.pageVPad)
        }
        .appBackground()
        .confirmationDialog("از حساب سی‌نما در این دستگاه خارج شوید؟", isPresented: $confirmLogout, titleVisibility: .visible) {
            Button("خروج", role: .destructive) { Task { await app.logout() } }
            Button("انصراف", role: .cancel) {}
        }
    }

    private func account(_ u: User) -> some View {
        Card {
            HStack(spacing: 30) {
                AsyncImage(url: u.avatar) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    ZStack {
                        Theme.cardStrong
                        Image(systemName: "person.fill").foregroundStyle(Theme.textDim)
                    }
                }
                .frame(width: Metrics.avatar, height: Metrics.avatar)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(Theme.red, lineWidth: 3))

                VStack(alignment: .leading, spacing: 10) {
                    Text(u.name).font(.appTitle2)
                    HStack(spacing: 12) {
                        Badge(text: "اشتراک \(plans[u.type] ?? u.type)", kind: .solid, icon: "crown.fill")
                        if let d = u.daysLeft { Badge(text: "\(d) روز باقی‌مانده", kind: .glass) }
                        if let e = u.expiresOn { Badge(text: "تا \(e)", kind: .glass) }
                    }
                    if !u.allowedToStream { Text("پخش آنلاین برای این حساب فعال نیست").font(.appCallout).foregroundStyle(Theme.red) }
                }
            }
        }
    }

    private func setting<T: Hashable>(_ title: String, icon: String, options: [T], selection: T, label: @escaping (T) -> String, onPick: @escaping (T) -> Void) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 18) {
                Label(title, systemImage: icon).font(.appHeadline)
                ChoiceRow(options: options, selection: selection, label: label, onPick: onPick)
            }
        }
        .tvFocusSection()
    }
}
