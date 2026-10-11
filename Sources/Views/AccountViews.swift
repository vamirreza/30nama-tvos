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
                Text("لیست من").font(.largeTitle.bold())
                Picker("", selection: $tab) {
                    ForEach(Tab.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .focusSection()

                PagedGrid(empty: tab.empty, onSelect: selectHandler, fetch: fetch(tab))
                .id("\(tab.rawValue)-\(reload)")
            }
            .padding(.horizontal, 80)
            .padding(.vertical, 40)
        }
        .navigationDestination(item: $detail) { TitleView(id: $0) }
        .confirmationDialog(
            picked.map { $0.name + ($0.episodeTitle.map { " · \($0)" } ?? "") } ?? "",
            isPresented: Binding(get: { picked != nil }, set: { if !$0 { picked = nil } }),
            titleVisibility: .visible
        ) {
            if let t = picked {
                Button("▶ ادامه پخش") { router.play(t.id) }
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
            VStack(alignment: .leading, spacing: 24) {
                Text("اعلان‌ها").font(.largeTitle.bold())
                if let error { Text(error).foregroundStyle(.red) }
                if loaded && items.isEmpty { Text("اعلان تازه‌ای ندارید.").foregroundStyle(.secondary) }
                if !loaded && error == nil { ProgressView().frame(maxWidth: .infinity).padding(60) }
                ForEach(items) { n in
                    Button { open(n) } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(n.title).font(.headline)
                                Spacer()
                                Text(n.date).font(.caption).foregroundStyle(.secondary)
                            }
                            if !n.text.isEmpty { Text(n.text).font(.callout).foregroundStyle(.secondary) }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                    }
                    .opacity(n.read ? 0.7 : 1)
                }
            }
            .padding(.horizontal, 80)
            .padding(.vertical, 40)
        }
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
            VStack(alignment: .leading, spacing: 36) {
                Text("حساب و تنظیمات").font(.largeTitle.bold())
                if let u = app.user { account(u) }

                setting("زیرنویس پیش‌فرض", selection: $settings.subLang, options: SubLang.allCases) { $0.label }
                setting("اندازه زیرنویس", selection: $settings.subSize, options: SubSize.allCases) { $0.label }
                setting("صدا", selection: $settings.audio, options: AudioPref.allCases) { $0.label }
                setting("کیفیت تصویر", selection: $settings.quality, options: Quality.allCases) { $0.label }

                Button("خروج از حساب") { confirmLogout = true }
            }
            .padding(.horizontal, 80)
            .padding(.vertical, 40)
        }
        .confirmationDialog("از حساب سی‌نما در این تلویزیون خارج شوید؟", isPresented: $confirmLogout, titleVisibility: .visible) {
            Button("خروج", role: .destructive) { Task { await app.logout() } }
            Button("انصراف", role: .cancel) {}
        }
    }

    private func account(_ u: User) -> some View {
        HStack(spacing: 30) {
            AsyncImage(url: u.avatar) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.white.opacity(0.1)
            }
            .frame(width: 120, height: 120)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 8) {
                Text(u.name).font(.title2.bold())
                MetaLine(parts: [
                    "اشتراک \(plans[u.type] ?? u.type)",
                    u.daysLeft.map { "\($0) روز باقی‌مانده" } ?? "",
                    u.expiresOn.map { "تا \($0)" } ?? "",
                ])
                if !u.allowedToStream { Text("پخش آنلاین برای این حساب فعال نیست").foregroundStyle(.red) }
            }
        }
    }

    private func setting<T: Hashable>(_ title: String, selection: Binding<T>, options: [T], label: @escaping (T) -> String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.title3.bold())
            Picker(title, selection: selection) {
                ForEach(options, id: \.self) { Text(label($0)).tag($0) }
            }
            .pickerStyle(.segmented)
        }
        .focusSection()
    }
}
