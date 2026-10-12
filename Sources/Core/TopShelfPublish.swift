import Foundation
import ImageIO

#if os(tvOS)
import UIKit

/// The app draws the Top Shelf artwork. The extension itself only has about 25 MB to work with,
/// far too little to decode and draw covers, so it just reads the finished files.
enum TopShelfArtwork {
    static let size = CGSize(width: 1920, height: 720)

    private static func downsampled(_ data: Data, maxPixel: CGFloat) -> UIImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: image)
    }

    static func render(_ item: TopShelfItem) async -> String? {
        var request = URLRequest(url: item.imageURL)
        request.timeoutInterval = 8
        let data: Data
        do { data = try await URLSession.shared.data(for: request).0 } catch {
            NSLog("[topshelf] download failed for \(item.id): \(error)")
            return nil
        }
        guard let cover = downsampled(data, maxPixel: 1920) else { NSLog("[topshelf] not an image: \(item.id)"); return nil }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
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
            // Measure first so the two lines are centred as a block, bottom-aligned just above the buttons.
            let shadow = NSShadow()
            shadow.shadowColor = UIColor.black.withAlphaComponent(0.7)
            shadow.shadowBlurRadius = 12
            shadow.shadowOffset = .zero
            func block(_ text: String, _ attrs: [NSAttributedString.Key: Any]) -> (NSAttributedString, CGSize) {
                var attrs = attrs
                attrs[.shadow] = shadow
                let string = NSAttributedString(string: text, attributes: attrs)
                let box = string.boundingRect(with: CGSize(width: textWidth, height: 200), options: [.usesLineFragmentOrigin], context: nil)
                return (string, CGSize(width: textWidth, height: ceil(box.height)))
            }
            let (titleText, titleSize) = block(item.title, titleAttrs(fontSize))
            let (subText, subSize) = block(item.subtitle, subAttrs)
            let gap: CGFloat = 10
            let bottom: CGFloat = 535
            let left = (size.width - textWidth) / 2
            subText.draw(with: CGRect(x: left, y: bottom - subSize.height, width: textWidth, height: subSize.height), options: [.usesLineFragmentOrigin], context: nil)
            titleText.draw(with: CGRect(x: left, y: bottom - subSize.height - gap - titleSize.height, width: textWidth, height: titleSize.height), options: [.usesLineFragmentOrigin], context: nil)
        }

        guard let dir = TopShelfStore.directory else { return nil }
        let file = dir.appendingPathComponent("shelf-\(item.id).jpg")
        do { try image.jpegData(compressionQuality: 0.85)?.write(to: file, options: .atomic) } catch {
            NSLog("[topshelf] write failed for \(item.id): \(error)")
            return nil
        }
        return file.lastPathComponent
    }
}
#endif

extension TopShelfStore {
    /// Publishes the featured titles for the Apple TV Top Shelf.
    static func save(_ titles: [Title]) {
        #if os(tvOS)
        let picked = titles.compactMap { t -> TopShelfItem? in
            guard let url = t.cover ?? t.posterLarge else { return nil }
            let sub = [t.year.map { "\($0)" }, t.imdb.flatMap { $0 > 0 ? $0 : nil }.map { "IMDb \($0)" }].compactMap { $0 }.joined(separator: "  ·  ")
            return TopShelfItem(id: t.id, title: t.english, subtitle: sub, imageURL: url)
        }.prefix(8)
        Task.detached {
            var items: [TopShelfItem] = []
            for var item in picked {
                item.file = await TopShelfArtwork.render(item)
                if item.file != nil { items.append(item) }
            }
            trace("app: drew \(items.count) cards")
            write(items)
        }
        #endif
    }
}
