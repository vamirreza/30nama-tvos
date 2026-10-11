import Foundation
import SwiftUI

/// What is on screen, and what a player may be opened for.
struct PlayerRequest: Identifiable {
    let id = UUID()
    let postId: Int
    let fileId: Int?
}

@MainActor
final class Router: ObservableObject {
    @Published var player: PlayerRequest?

    /// With no file, the player resumes from the stream's saved episode and position.
    func play(_ postId: Int, fileId: Int? = nil) {
        player = PlayerRequest(postId: postId, fileId: fileId)
    }
}

@MainActor
final class AppState: ObservableObject {
    enum Phase {
        case needsKey, loggedOut, loading, ready
        case failed(String)
    }

    @Published var phase: Phase
    @Published var user: User?

    init() {
        if Config.apiKey.isEmpty { phase = .needsKey }
        else if SessionStore.token == nil { phase = .loggedOut }
        else { phase = .loading }
    }

    func start() async {
        if case .loading = phase { await loadUser() }
    }

    func saveKey(_ key: String) {
        Config.saveAPIKey(key)
        phase = SessionStore.token == nil ? .loggedOut : .loading
        if case .loading = phase { Task { await loadUser() } }
    }

    func loggedIn(token: String) {
        SessionStore.token = token
        phase = .loading
        Task { await loadUser() }
    }

    func loadUser() async {
        phase = .loading
        do {
            user = try await API.user()
            phase = .ready
        } catch let e as APIError where e.kind == .unauthorized || e.message.contains("ابتدا وارد") {
            // An expired or revoked session sends the viewer back to the QR screen.
            SessionStore.token = nil
            user = nil
            phase = .loggedOut
        } catch {
            if let m = describe(error) { phase = .failed(m) }
        }
    }

    func logout() async {
        _ = try? await API.logout()
        SessionStore.token = nil
        user = nil
        phase = .loggedOut
    }
}
