import TVServices
import UIKit

/// The Apple TV home-screen carousel: the featured titles the app last loaded.
/// With nothing saved yet it returns nil and the system shows the static Top Shelf image.
final class ContentProvider: TVTopShelfContentProvider {
    private static let size = CGSize(width: 1920, height: 720)

    override func loadTopShelfContent() async -> TVTopShelfContent? {
        let items = TopShelfStore.load()
        guard !items.isEmpty else { return nil }

        // Artwork with the title drawn on it, so every card reads without relying on system text.
        var files: [Int: URL] = [:]
        await withTaskGroup(of: (Int, URL?).self) { group in
            for item in items { group.addTask { (item.id, await Self.render(item)) } }
            for await (id, url) in group { if let url { files[id] = url } }
        }

        let cards = items.compactMap { item -> TVTopShelfCarouselItem? in
            // If the artwork could not be drawn, the plain cover still beats an empty shelf.
            let file = files[item.id] ?? item.imageURL
            let card = TVTopShelfCarouselItem(identifier: "\(item.id)")
            card.setImageURL(file, for: .screenScale1x)
            card.setImageURL(file, for: .screenScale2x)
            if let url = URL(string: "sinama://play/\(item.id)") {
                card.playAction = TVTopShelfAction(url: url)
                card.displayAction = TVTopShelfAction(url: url)
            }
            return card
        }
        guard !cards.isEmpty else { return nil }
        return TVTopShelfCarouselContent(style: .actions, items: cards)
    }

    private static func render(_ item: TopShelfItem) async -> URL? {
        var request = URLRequest(url: item.imageURL)
        request.timeoutInterval = 8
        let data: Data
        do { data = try await URLSession.shared.data(for: request).0 } catch {
            NSLog("[topshelf] download failed for \(item.id): \(error)")
            return nil
        }
        guard let cover = UIImage(data: data) else { NSLog("[topshelf] not an image: \(item.id)"); return nil }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            // Fill, anchored near the top so faces stay in frame.
            let scale = max(size.width / cover.size.width, size.height / cover.size.height)
            let w = cover.size.width * scale, h = cover.size.height * scale
            cover.draw(in: CGRect(x: (size.width - w) / 2, y: -(h - size.height) * 0.25, width: w, height: h))

            // Darken the bottom and the leading side for the text.
            let colors = [UIColor.black.withAlphaComponent(0).cgColor, UIColor.black.withAlphaComponent(0.85).cgColor] as CFArray
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
            ctx.cgContext.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size.height * 0.4), end: CGPoint(x: 0, y: size.height), options: [])

            // The shelf shows this artwork cropped to 16:9, so only the middle ~1280 pt is always visible,
            // and the system's Play / More Info buttons sit at the bottom centre.
            let textWidth: CGFloat = 1100
            let center = NSMutableParagraphStyle()
            center.alignment = .center
            center.lineBreakMode = .byTruncatingTail

            var fontSize: CGFloat = 76
            func titleAttrs(_ size: CGFloat) -> [NSAttributedString.Key: Any] {
                [.font: UIFont.systemFont(ofSize: size, weight: .bold), .foregroundColor: UIColor.white, .paragraphStyle: center]
            }
            while fontSize > 44, (item.title as NSString).size(withAttributes: titleAttrs(fontSize)).width > textWidth { fontSize -= 4 }

            let subAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 36, weight: .medium),
                .foregroundColor: UIColor.white.withAlphaComponent(0.8),
                .paragraphStyle: center,
            ]
            let left = (size.width - textWidth) / 2
            (item.title as NSString).draw(in: CGRect(x: left, y: 395, width: textWidth, height: 95), withAttributes: titleAttrs(fontSize))
            (item.subtitle as NSString).draw(in: CGRect(x: left, y: 490, width: textWidth, height: 50), withAttributes: subAttrs)
        }

        let dir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: TopShelfStore.group) ?? FileManager.default.temporaryDirectory
        let file = dir.appendingPathComponent("shelf-\(item.id).jpg")
        do { try image.jpegData(compressionQuality: 0.85)?.write(to: file, options: .atomic) } catch {
            NSLog("[topshelf] write failed for \(item.id): \(error)")
            return nil
        }
        return file
    }
}
