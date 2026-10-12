import Foundation
#if os(tvOS)
import TVServices
#endif

/// What the Top Shelf extension shows. The app writes it into the shared app-group container.
struct TopShelfItem: Codable {
    let id: Int
    let title: String
    let subtitle: String
    let imageURL: URL
    var genre: String? = nil
}

enum TopShelfStore {
    static let group = "group.com.vamirreza.sinama"
    private static var file: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)?.appendingPathComponent("topshelf.json")
    }

    static func write(_ items: [TopShelfItem]) {
        #if os(tvOS)
        guard let file, let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: file, options: .atomic)
        TVTopShelfContentProvider.topShelfContentDidChange()
        #endif
    }

    static func load() -> [TopShelfItem] {
        guard let file, let data = try? Data(contentsOf: file) else { return [] }
        return (try? JSONDecoder().decode([TopShelfItem].self, from: data)) ?? []
    }
}
