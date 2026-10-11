import SwiftUI

/// Layout sizes. tvOS is laid out for a 1920×1080 canvas viewed from a sofa; iOS for a hand-held screen.
enum Metrics {
    #if os(tvOS)
    static let pagePad: CGFloat = 80
    static let pageVPad: CGFloat = 40
    static let rowGap: CGFloat = 40
    static let rowVPad: CGFloat = 30
    static let posterWidth: CGFloat = 230
    static let gridMin: CGFloat = 230
    static let gridMax: CGFloat = 240
    static let gridGap: CGFloat = 40
    static let gridRowGap: CGFloat = 50
    static let heroHeight: CGFloat = 680
    static let heroTextWidth: CGFloat = 1000
    static let sectionGap: CGFloat = 40
    static let titlePosterWidth: CGFloat = 360
    static let titlePosterHeight: CGFloat = 540
    static let episodeWidth: CGFloat = 320
    static let episodeHeight: CGFloat = 150
    static let tileWidth: CGFloat = 300
    static let tileHeight: CGFloat = 170
    static let tileMin: CGFloat = 300
    static let tileMax: CGFloat = 340
    static let chipMin: CGFloat = 200
    static let avatar: CGFloat = 120
    static let itemSpacing: CGFloat = 24
    static let accentWidth: CGFloat = 8
    static let accentHeight: CGFloat = 38
    static let badgeH: CGFloat = 14
    static let badgeV: CGFloat = 6
    static let badgeGap: CGFloat = 16
    static let cardPad: CGFloat = 36
    static let heroLogoPad: CGFloat = 60
    static let stepBadge: CGFloat = 52
    static let emptyIcon: CGFloat = 64
    static let launchLogo: CGFloat = 130
    #else
    static let pagePad: CGFloat = 16
    static let pageVPad: CGFloat = 12
    static let rowGap: CGFloat = 12
    static let rowVPad: CGFloat = 8
    static let posterWidth: CGFloat = 120
    static let gridMin: CGFloat = 104
    static let gridMax: CGFloat = 170
    static let gridGap: CGFloat = 12
    static let gridRowGap: CGFloat = 16
    static let heroHeight: CGFloat = 420
    static let heroTextWidth: CGFloat = .infinity
    static let sectionGap: CGFloat = 22
    static let titlePosterWidth: CGFloat = 150
    static let titlePosterHeight: CGFloat = 225
    static let episodeWidth: CGFloat = 150
    static let episodeHeight: CGFloat = 78
    static let tileWidth: CGFloat = 160
    static let tileHeight: CGFloat = 90
    static let tileMin: CGFloat = 150
    static let tileMax: CGFloat = 260
    static let chipMin: CGFloat = 96
    static let avatar: CGFloat = 64
    static let itemSpacing: CGFloat = 10
    static let accentWidth: CGFloat = 4
    static let accentHeight: CGFloat = 20
    static let badgeH: CGFloat = 8
    static let badgeV: CGFloat = 3
    static let badgeGap: CGFloat = 10
    static let cardPad: CGFloat = 16
    static let heroLogoPad: CGFloat = 14
    static let stepBadge: CGFloat = 32
    static let emptyIcon: CGFloat = 40
    static let launchLogo: CGFloat = 56
    #endif
}

extension View {
    /// Poster/tile buttons draw their own artwork, so they take no button chrome.
    func posterButtonStyle() -> some View {
        buttonStyle(.poster)
    }

    func tileButtonStyle() -> some View {
        buttonStyle(.poster)
    }

    /// Lets a horizontal row's focus/hover scale spill past its bounds on tvOS only.
    func rowClipDisabled() -> some View {
        #if os(tvOS)
        scrollClipDisabled()
        #else
        self
        #endif
    }
}

extension View {
    /// Groups views for the tvOS focus engine; touch screens have no focus to steer.
    func tvFocusSection() -> some View {
        #if os(tvOS)
        focusSection()
        #else
        self
        #endif
    }
}
