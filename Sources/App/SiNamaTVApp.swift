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
                .environmentObject(app)
                .environmentObject(router)
                .environmentObject(settings)
                // The interface is Persian and right-to-left.
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.locale, Locale(identifier: "fa"))
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

    var body: some View {
        TabView {
            Nav { HomeView() }.tabItem { Label("خانه", systemImage: "house") }
            Nav { SearchView() }.tabItem { Label("جستجو", systemImage: "magnifyingglass") }
            Nav { BrowseView() }.tabItem { Label("دسته‌بندی", systemImage: "square.grid.2x2") }
            Nav { MyListView() }.tabItem { Label("لیست من", systemImage: "bookmark") }
            #if os(tvOS)
            Nav { NotificationsView() }.tabItem { Label("اعلان‌ها", systemImage: "bell") }
            #endif
            Nav { ProfileView() }.tabItem { Label("حساب", systemImage: "person.crop.circle") }
        }
    }
}
