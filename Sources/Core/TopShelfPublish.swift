import Foundation

extension TopShelfStore {
    /// Publishes the featured titles for the Apple TV Top Shelf.
    static func save(_ titles: [Title]) {
        let items = titles.prefix(12).compactMap { t -> TopShelfItem? in
            guard let url = t.cover ?? t.posterLarge else { return nil }
            let sub = [t.year.map { "\($0)" }, t.imdb.map { "IMDb \($0)" }].compactMap { $0 }.joined(separator: "  ·  ")
            return TopShelfItem(id: t.id, title: t.name, subtitle: sub, imageURL: url)
        }
        write(items)
    }
}
