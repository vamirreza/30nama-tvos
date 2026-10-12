import SwiftUI
import ImageIO

/// Downloads, downsamples and caches artwork. `AsyncImage` re-fetches and decodes full-size images
/// every time a cell scrolls back in, which is what makes long rows stutter on an Apple TV HD.
final class ImageStore {
    static let shared = ImageStore()

    private let cache = NSCache<NSString, UIImage>()
    private let session: URLSession

    private init() {
        cache.totalCostLimit = 120 * 1024 * 1024   // decoded bytes
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(memoryCapacity: 30 * 1024 * 1024, diskCapacity: 300 * 1024 * 1024)
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.httpMaximumConnectionsPerHost = 6
        session = URLSession(configuration: config)
    }

    func cached(_ url: URL, maxPixel: Int) -> UIImage? {
        cache.object(forKey: key(url, maxPixel))
    }

    func load(_ url: URL, maxPixel: Int) async -> UIImage? {
        if let hit = cached(url, maxPixel: maxPixel) { return hit }
        guard let (data, _) = try? await session.data(from: url), !Task.isCancelled else { return nil }
        // Decode at the size it will be shown, away from the main thread.
        let image = await Task.detached(priority: .userInitiated) { Self.downsample(data, maxPixel: maxPixel) }.value
        if let image {
            cache.setObject(image, forKey: key(url, maxPixel), cost: Int(image.size.width * image.size.height * image.scale * image.scale * 4))
        }
        return image
    }

    private func key(_ url: URL, _ maxPixel: Int) -> NSString { "\(maxPixel)|\(url.absoluteString)" as NSString }

    private static func downsample(_ data: Data, maxPixel: Int) -> UIImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,   // decode now, not on first draw
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: cg)
    }
}

/// Fills its frame with the artwork (like `scaledToFill`), showing `placeholder` until it arrives.
struct RemoteImage<Placeholder: View>: View {
    let url: URL?
    let maxPixel: Int
    @ViewBuilder var placeholder: () -> Placeholder
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            guard let url else { image = nil; return }
            if let hit = ImageStore.shared.cached(url, maxPixel: maxPixel) { image = hit; return }
            image = await ImageStore.shared.load(url, maxPixel: maxPixel)
        }
    }
}
