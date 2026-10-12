import TVServices

/// The Apple TV home-screen carousel: the featured titles the app last loaded.
/// With nothing saved yet it returns nil and the system shows the static Top Shelf image.
final class ContentProvider: TVTopShelfContentProvider {
    override func loadTopShelfContent() async -> TVTopShelfContent? {
        let items = TopShelfStore.load()
        guard !items.isEmpty else { return nil }
        let cards = items.map { item -> TVTopShelfCarouselItem in
            let card = TVTopShelfCarouselItem(identifier: "\(item.id)")
            card.title = item.title
            card.summary = item.subtitle
            card.genre = item.genre
            card.setImageURL(item.imageURL, for: .screenScale1x)
            card.setImageURL(item.imageURL, for: .screenScale2x)
            if let url = URL(string: "sinama://play/\(item.id)") {
                card.playAction = TVTopShelfAction(url: url)
                card.displayAction = TVTopShelfAction(url: url)
            }
            return card
        }
        return TVTopShelfCarouselContent(style: .details, items: cards)
    }
}
