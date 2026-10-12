import SwiftUI
import UIKit

@main
struct SiNamaTVApp: App {
    @StateObject private var app = AppState()
    @StateObject private var router = Router()
    @StateObject private var settings = SettingsStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                // A new identity rebuilds every screen, so all strings pick up the new language.
                .id(settings.language)
                .environmentObject(app)
                .environmentObject(router)
                .environmentObject(settings)
                // Persian is right-to-left, English left-to-right.
                .environment(\.layoutDirection, settings.language.layoutDirection)
                .environment(\.locale, settings.language.locale)
                .preferredColorScheme(.dark)
                .font(.appBody)
                .tint(Theme.red)
                .buttonStyle(.pill)
                .onOpenURL { url in
                    // sinama://play/<id> comes from the Top Shelf.
                    if url.host == "play", let id = Int(url.lastPathComponent) { router.play(id) }
                }
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
            case .loading: LaunchView()
            case .failed(let message): ErrorNote(message: message) { Task { await app.loadUser() } }
            case .ready: MainTabs()
            }
        }
        .task { TopShelfStore.trace("app: launched"); await app.start() }
        .fullScreenCover(item: $router.player) { request in
            PlayerScreen(request: request, userId: app.user?.id, settings: settings) { router.player = nil }
                .ignoresSafeArea()
        }
    }
}

struct MainTabs: View {
    init() {
        #if os(iOS)
        let bar = UITabBarAppearance()
        bar.configureWithOpaqueBackground()
        bar.backgroundColor = UIColor(red: 0.043, green: 0.043, blue: 0.063, alpha: 0.96)
        UITabBar.appearance().standardAppearance = bar
        UITabBar.appearance().scrollEdgeAppearance = bar
        #endif
    }

    // Kept in the router so a language switch (which rebuilds the UI) leaves you on the same tab.
    @EnvironmentObject private var router: Router

    var body: some View {
        TabView(selection: $router.tab) {
            Nav { HomeView() }.tabItem { Label(tr("خانه"), systemImage: "house") }.tag(0)
            Nav { SearchView() }.tabItem { Label(tr("جستجو"), systemImage: "magnifyingglass") }.tag(1)
            Nav { BrowseView() }.tabItem { Label(tr("دسته‌بندی"), systemImage: "square.grid.2x2") }.tag(2)
            Nav { MyListView() }.tabItem { Label(tr("لیست من"), systemImage: "bookmark") }.tag(3)
            Nav { ProfileView() }.tabItem { Label(tr("حساب"), systemImage: "person.crop.circle") }.tag(5)
        }
    }
}
