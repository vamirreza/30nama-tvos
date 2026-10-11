#if os(iOS)
import UIKit

/// Controls the system player does not offer on iPhone: close, a menu for episodes / subtitles /
/// quality, and the skip-intro / next-episode buttons. Sits above the player and lets every touch
/// outside its own buttons fall through to AVPlayerViewController.
final class PlayerChrome: UIView, UIGestureRecognizerDelegate {
    private let closeButton = UIButton(type: .system)
    private let menuButton = UIButton(type: .system)
    private let actionStack = UIStackView()
    private var hideWork: DispatchWorkItem?
    private let onClose: () -> Void

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        build()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    private func chromeButton(_ button: UIButton, symbol: String) {
        var config = UIButton.Configuration.filled()
        config.image = UIImage(systemName: symbol)
        config.baseBackgroundColor = UIColor.black.withAlphaComponent(0.55)
        config.baseForegroundColor = .white
        config.cornerStyle = .capsule
        button.configuration = config
        button.translatesAutoresizingMaskIntoConstraints = false
        addSubview(button)
    }

    private func build() {
        chromeButton(closeButton, symbol: "xmark")
        closeButton.addAction(UIAction { [weak self] _ in self?.onClose() }, for: .touchUpInside)

        chromeButton(menuButton, symbol: "ellipsis")
        menuButton.showsMenuAsPrimaryAction = true
        menuButton.isHidden = true

        actionStack.axis = .horizontal
        actionStack.spacing = 12
        actionStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(actionStack)

        let guide = safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            closeButton.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            closeButton.topAnchor.constraint(equalTo: guide.topAnchor, constant: 12),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44),
            menuButton.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),
            menuButton.topAnchor.constraint(equalTo: guide.topAnchor, constant: 12),
            menuButton.widthAnchor.constraint(equalToConstant: 44),
            menuButton.heightAnchor.constraint(equalToConstant: 44),
            actionStack.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -24),
            actionStack.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -96),
        ])
        pulse()
    }

    // MARK: content

    func setMenus(_ items: [UIMenuElement]) {
        menuButton.menu = UIMenu(children: items)
        menuButton.isHidden = items.isEmpty
    }

    func setActions(_ actions: [UIAction]) {
        actionStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (i, action) in actions.enumerated() {
            var config = UIButton.Configuration.filled()
            config.title = action.title
            config.image = action.image
            config.imagePadding = 6
            config.cornerStyle = .capsule
            // The primary action (first) is bright; the secondary ("stay") is muted.
            config.baseBackgroundColor = i == 0 ? .white : UIColor.black.withAlphaComponent(0.6)
            config.baseForegroundColor = i == 0 ? .black : .white
            actionStack.addArrangedSubview(UIButton(configuration: config, primaryAction: action))
        }
    }

    // MARK: visibility

    /// Shows the close and menu buttons, then fades them out again.
    @objc func pulse() {
        hideWork?.cancel()
        UIView.animate(withDuration: 0.2) {
            self.closeButton.alpha = 1
            self.menuButton.alpha = 1
        }
        let work = DispatchWorkItem { [weak self] in
            UIView.animate(withDuration: 0.4) {
                self?.closeButton.alpha = 0
                self?.menuButton.alpha = 0
            }
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: work)
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        // Faded-out buttons must not swallow taps meant for the player.
        if let hit, hit === closeButton || hit === menuButton, hit.alpha < 0.1 { return nil }
        return hit === self ? nil : hit
    }

    func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
}
#endif
