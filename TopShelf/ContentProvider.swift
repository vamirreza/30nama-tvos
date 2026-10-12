import TVServices

/// The Apple TV home-screen carousel: the featured titles the app last prepared.
/// It must stay tiny (the system kills Top Shelf extensions above ~25 MB), so it only reads files
/// the app drew. With nothing saved yet it returns nil.
final class ContentProvider: TVTopShelfContentProvider {
    override func loadTopShelfContent() async -> TVTopShelfContent? {
        let items = TopShelfStore.load()
        guard let dir = TopShelfStore.directory else { return nil }

        let cards = items.compactMap { item -> TVTopShelfCarouselItem? in
            guard let name = item.file else { return nil }
            let file = dir.appendingPathComponent(name)
            guard FileManager.default.fileExists(atPath: file.path) else { return nil }
            let card = TVTopShelfCarouselItem(identifier: "\(item.id)")
            card.setImageURL(file, for: .screenScale1x)
            card.setImageURL(file, for: .screenScale2x)
            if let url = URL(string: "sinama://play/\(item.id)") {
                card.playAction = TVTopShelfAction(url: url)
                card.displayAction = TVTopShelfAction(url: url)
            }
            return card
        }
        TopShelfStore.trace("extension: \(cards.count) cards")
        guard !cards.isEmpty else { return nil }
        return TVTopShelfCarouselContent(style: .actions, items: cards)
    }
}
