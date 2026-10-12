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
            ctx.cgContext.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size.height * 0.35), end: CGPoint(x: 0, y: size.height), options: [])

            let titleStyle = NSMutableParagraphStyle()
            titleStyle.lineBreakMode = .byTruncatingTail
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 76, weight: .bold),
                .foregroundColor: UIColor.white,
                .paragraphStyle: titleStyle,
            ]
            let subAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 38, weight: .medium),
                .foregroundColor: UIColor.white.withAlphaComponent(0.75),
            ]
            let textWidth = size.width - 240
            let subtitle = [item.subtitle].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "  ·  ")
            (item.title as NSString).draw(in: CGRect(x: 120, y: size.height - 335, width: textWidth, height: 100), withAttributes: titleAttrs)
            (subtitle as NSString).draw(in: CGRect(x: 120, y: size.height - 235, width: textWidth, height: 60), withAttributes: subAttrs)
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
