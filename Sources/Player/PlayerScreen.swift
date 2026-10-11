import AVKit
import SwiftUI
import UIKit

/// Hosts the system player so the Siri Remote, transport bar and Menu button behave natively.
final class PlayerHostController: UIViewController {
    let playerVC = AVPlayerViewController()
    var engine: PlayerEngine?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        addChild(playerVC)
        playerVC.view.frame = view.bounds
        playerVC.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(playerVC.view)
        playerVC.didMove(toParent: self)
    }

    override var preferredFocusEnvironments: [UIFocusEnvironment] { [playerVC] }
}

struct PlayerScreen: UIViewControllerRepresentable {
    let request: PlayerRequest
    let userId: Int?
    let settings: SettingsStore
    let onClose: () -> Void

    func makeUIViewController(context: Context) -> PlayerHostController {
        let host = PlayerHostController()
        host.loadViewIfNeeded()
        let engine = PlayerEngine(
            postId: request.postId,
            fileId: request.fileId,
            userId: userId,
            settings: settings,
            playerVC: host.playerVC,
            onClose: onClose
        )
        host.engine = engine
        engine.start()
        return host
    }

    func updateUIViewController(_ host: PlayerHostController, context: Context) {}

    static func dismantleUIViewController(_ host: PlayerHostController, coordinator: ()) {
        host.engine?.shutdown()
    }
}
