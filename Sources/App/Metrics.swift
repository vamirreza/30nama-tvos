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
    static let episodeWidth: CGFloat = 240
    static let episodeHeight: CGFloat = 120
    static let tileWidth: CGFloat = 300
    static let tileHeight: CGFloat = 170
    static let tileMin: CGFloat = 300
    static let tileMax: CGFloat = 340
    static let chipMin: CGFloat = 200
    static let avatar: CGFloat = 120
    static let itemSpacing: CGFloat = 24
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
    static let episodeWidth: CGFloat = 130
    static let episodeHeight: CGFloat = 64
    static let tileWidth: CGFloat = 160
    static let tileHeight: CGFloat = 90
    static let tileMin: CGFloat = 150
    static let tileMax: CGFloat = 260
    static let chipMin: CGFloat = 96
    static let avatar: CGFloat = 64
    static let itemSpacing: CGFloat = 12
    #endif
}

extension View {
    /// Poster/tile buttons draw their own artwork, so they take no button chrome.
    func posterButtonStyle() -> some View {
        #if os(tvOS)
        buttonStyle(.borderless)
        #else
        buttonStyle(.plain)
        #endif
    }

    func tileButtonStyle() -> some View {
        #if os(tvOS)
        buttonStyle(.card)
        #else
        buttonStyle(.plain)
        #endif
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
