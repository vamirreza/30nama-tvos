import SwiftUI

@main
struct SiNamaTVApp: App {
    @StateObject private var app = AppState()
    @StateObject private var router = Router()
    @StateObject private var settings = SettingsStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
                .environmentObject(router)
                .environmentObject(settings)
                // The interface is Persian and right-to-left.
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.locale, Locale(identifier: "fa"))
                .preferredColorScheme(.dark)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        Group {
            switch app.phase {
            case .needsKey: APIKeyView()
            case .loggedOut: LoginView()
            case .loading: ProgressView()
            case .failed(let message): ErrorNote(message: message) { Task { await app.loadUser() } }
            case .ready: MainTabs()
            }
        }
        .task { await app.start() }
        .fullScreenCover(item: $router.player) { request in
            PlayerScreen(request: request, userId: app.user?.id, settings: settings) { router.player = nil }
                .ignoresSafeArea()
        }
    }
}

struct MainTabs: View {
    var body: some View {
        TabView {
            Nav { HomeView() }.tabItem { Label("خانه", systemImage: "house") }
            Nav { SearchView() }.tabItem { Label("جستجو", systemImage: "magnifyingglass") }
            Nav { BrowseView() }.tabItem { Label("دسته‌بندی", systemImage: "square.grid.2x2") }
            Nav { MyListView() }.tabItem { Label("لیست من", systemImage: "bookmark") }
            Nav { NotificationsView() }.tabItem { Label("اعلان‌ها", systemImage: "bell") }
            Nav { ProfileView() }.tabItem { Label("حساب", systemImage: "person.crop.circle") }
        }
    }
}
