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
    /// tvOS only lets apps write below Library/Caches, and that holds for the group container too.
    static var directory: URL? {
        guard let root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) else { return nil }
        let dir = root.appendingPathComponent("Library/Caches", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    private static var file: URL? { directory?.appendingPathComponent("topshelf.json") }

    /// A tiny trace both the app and the extension append to, readable from the group container.
    static func trace(_ message: String) {
        guard let dir = directory else { return }
        let file = dir.appendingPathComponent("topshelf.log")
        let line = "\(Date()) \(message)\n"
        if let handle = try? FileHandle(forWritingTo: file) {
            handle.seekToEndOfFile()
            handle.write(Data(line.utf8))
            try? handle.close()
        } else {
            try? Data(line.utf8).write(to: file)
        }
    }

    static func write(_ items: [TopShelfItem]) {
        #if os(tvOS)
        guard let file else { trace("app: no group container"); return }
        guard let data = try? JSONEncoder().encode(items) else { return }
        do { try data.write(to: file, options: .atomic); trace("app: wrote \(items.count) items") }
        catch { trace("app: write failed \(error)") }
        TVTopShelfContentProvider.topShelfContentDidChange()
        #endif
    }

    static func load() -> [TopShelfItem] {
        guard let file, let data = try? Data(contentsOf: file) else { return [] }
        return (try? JSONDecoder().decode([TopShelfItem].self, from: data)) ?? []
    }
}
