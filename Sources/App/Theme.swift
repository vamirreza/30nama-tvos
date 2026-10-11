import SwiftUI

/// The look of the app: the 30nama red on a near-black canvas, soft glass cards and one focus
/// language (white fill, gentle lift) shared by tvOS and iOS.
enum Theme {
    /// Sampled from the logo.
    static let red = Color(red: 0.816, green: 0.251, blue: 0.251)
    static let redDeep = Color(red: 0.55, green: 0.10, blue: 0.13)
    static let background = Color(red: 0.043, green: 0.043, blue: 0.063)
    static let card = Color.white.opacity(0.07)
    static let cardStrong = Color.white.opacity(0.12)
    static let stroke = Color.white.opacity(0.12)
    static let textDim = Color.white.opacity(0.66)
    static let gold = Color(red: 0.96, green: 0.77, blue: 0.09)

    #if os(tvOS)
    static let radius: CGFloat = 22
    static let pillH: CGFloat = 40
    static let pillV: CGFloat = 20
    static let chipH: CGFloat = 28
    static let chipV: CGFloat = 14
    static let focusScale: CGFloat = 1.08
    static let logoHeight: CGFloat = 64
    #else
    static let radius: CGFloat = 14
    static let pillH: CGFloat = 18
    static let pillV: CGFloat = 11
    static let chipH: CGFloat = 14
    static let chipV: CGFloat = 8
    static let focusScale: CGFloat = 1
    static let logoHeight: CGFloat = 26
    #endif
}

// MARK: - Backgrounds and logo

struct AppBackground: View {
    var body: some View {
        ZStack {
            Theme.background
            RadialGradient(colors: [Theme.redDeep.opacity(0.55), .clear], center: .topLeading, startRadius: 0, endRadius: 1100)
            RadialGradient(colors: [Theme.redDeep.opacity(0.25), .clear], center: .bottomTrailing, startRadius: 0, endRadius: 900)
        }
        .ignoresSafeArea()
    }
}

extension View {
    /// Paints the brand background behind a screen.
    func appBackground() -> some View { background(AppBackground()) }
}

/// The 30nama wordmark (Resources/Shared/Assets.xcassets/Logo).
struct Logo: View {
    var height: CGFloat = Theme.logoHeight
    var body: some View {
        Image("Logo").resizable().scaledToFit().frame(height: height)
            .accessibilityLabel("سی‌نما")
    }
}

/// Just the cube emblem, for tight spots.
struct LogoMark: View {
    var height: CGFloat = Theme.logoHeight
    var body: some View {
        Image("LogoMark").resizable().scaledToFit().frame(height: height)
            .accessibilityHidden(true)
    }
}

// MARK: - Button styles

/// Capsule button. Prominent is the 30nama red; both turn white and lift when focused.
struct PillButtonStyle: ButtonStyle {
    var prominent = false

    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        Body(configuration: configuration, prominent: prominent)
    }

    private struct Body: View {
        let configuration: ButtonStyleConfiguration
        let prominent: Bool
        @Environment(\.isFocused) private var focused
        @Environment(\.isEnabled) private var enabled

        var body: some View {
            configuration.label
                .font(.appHeadline)
                .lineLimit(1)
                .padding(.horizontal, Theme.pillH)
                .padding(.vertical, Theme.pillV)
                .foregroundStyle(focused ? Color.black : Color.white)
                .background(Capsule().fill(fill))
                .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: focused || prominent ? 0 : 1))
                .scaleEffect(focused ? Theme.focusScale : (configuration.isPressed ? 0.96 : 1))
                .shadow(color: .black.opacity(focused ? 0.45 : 0), radius: 22, y: 12)
                .opacity(enabled ? 1 : 0.45)
                .animation(.easeOut(duration: 0.16), value: focused)
        }

        private var fill: Color {
            if focused { return .white }
            return prominent ? Theme.red : Theme.cardStrong
        }
    }
}

/// Smaller selectable pill for filters, tabs and settings. `on` fills it red.
struct ChipButtonStyle: ButtonStyle {
    var on = false

    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        Body(configuration: configuration, on: on)
    }

    private struct Body: View {
        let configuration: ButtonStyleConfiguration
        let on: Bool
        @Environment(\.isFocused) private var focused

        var body: some View {
            configuration.label
                .font(.appCalloutMedium)
                .lineLimit(1)
                .padding(.horizontal, Theme.chipH)
                .padding(.vertical, Theme.chipV)
                .foregroundStyle(focused ? Color.black : Color.white)
                .background(Capsule().fill(focused ? Color.white : (on ? Theme.red : Theme.card)))
                .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: focused || on ? 0 : 1))
                .scaleEffect(focused ? Theme.focusScale : (configuration.isPressed ? 0.96 : 1))
                .shadow(color: .black.opacity(focused ? 0.4 : 0), radius: 16, y: 8)
                .animation(.easeOut(duration: 0.16), value: focused)
        }
    }
}

/// For artwork buttons (posters, tiles, cards): rounded, hairline border, lifts and glows on focus.
struct PosterButtonStyle: ButtonStyle {
    var radius: CGFloat = Theme.radius

    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        Body(configuration: configuration, radius: radius)
    }

    private struct Body: View {
        let configuration: ButtonStyleConfiguration
        let radius: CGFloat
        @Environment(\.isFocused) private var focused

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
            configuration.label
                .clipShape(shape)
                .overlay(shape.strokeBorder(focused ? Color.white : Theme.stroke, lineWidth: focused ? 4 : 1))
                .shadow(color: .black.opacity(focused ? 0.6 : 0.35), radius: focused ? 30 : 10, y: focused ? 18 : 6)
                .scaleEffect(focused ? Theme.focusScale : (configuration.isPressed ? 0.97 : 1))
                .animation(.easeOut(duration: 0.16), value: focused)
        }
    }
}

extension ButtonStyle where Self == PillButtonStyle {
    static var pill: PillButtonStyle { PillButtonStyle() }
    static var pillProminent: PillButtonStyle { PillButtonStyle(prominent: true) }
}

extension ButtonStyle where Self == PosterButtonStyle {
    static var poster: PosterButtonStyle { PosterButtonStyle() }
}

// MARK: - Small pieces

/// Section title with a red accent bar.
struct SectionHeader: View {
    let title: String
    var body: some View {
        HStack(spacing: 14) {
            Capsule().fill(Theme.red).frame(width: Metrics.accentWidth, height: Metrics.accentHeight)
            Text(title).font(.appTitle3Bold)
        }
    }
}

/// Small label: IMDb score, age rating, subtitle availability.
struct Badge: View {
    enum Kind { case imdb, solid, outline, glass }
    let text: String
    var kind: Kind = .glass
    var icon: String?

    var body: some View {
        HStack(spacing: 6) {
            if let icon { Image(systemName: icon) }
            Text(text)
        }
        .font(.appCaption2Bold)
        .padding(.horizontal, Metrics.badgeH)
        .padding(.vertical, Metrics.badgeV)
        .foregroundStyle(kind == .imdb ? Color.black : Color.white)
        .background(background, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(kind == .outline ? Color.white.opacity(0.5) : .clear, lineWidth: 1.5))
    }

    private var background: Color {
        switch kind {
        case .imdb: return Theme.gold
        case .solid: return Theme.red
        case .outline: return .clear
        case .glass: return Color.white.opacity(0.16)
        }
    }
}

/// Year, runtime and score badges for a title; falls back to a scroll when a phone is too narrow.
struct MetaBadges: View {
    let title: Title

    private var row: some View {
        HStack(spacing: Metrics.badgeGap) {
            if let y = title.year {
                Text("\(y)" + (title.yearEnd.map { "–\($0)" } ?? "")).font(.appCalloutMedium).foregroundStyle(Theme.textDim)
            }
            if let m = title.minutes { Text("\(m) دقیقه").font(.appCalloutMedium).foregroundStyle(Theme.textDim) }
            if let age = title.age, !age.isEmpty { Badge(text: age, kind: .outline) }
            if let s = title.imdb { Badge(text: "IMDb \(s)", kind: .imdb) }
            if let s = title.nama30 { Badge(text: "سی‌نما \(s)", kind: .solid) }
            if title.persianSubtitle { Badge(text: "زیرنویس فارسی", kind: .glass, icon: "captions.bubble.fill") }
        }
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            row
            ScrollView(.horizontal, showsIndicators: false) { row }
        }
    }
}

/// A wrapped row of selectable chips for settings and tabs.
struct ChoiceRow<T: Hashable>: View {
    let options: [T]
    let selection: T
    let label: (T) -> String
    let onPick: (T) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: Metrics.chipMin), spacing: Metrics.itemSpacing)], alignment: .leading, spacing: Metrics.itemSpacing) {
            ForEach(options, id: \.self) { o in
                ChipButton(label: label(o), on: o == selection) { onPick(o) }
            }
        }
    }
}

/// A rounded glass panel.
struct Card<Content: View>: View {
    private let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content
            .padding(Metrics.cardPad)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).strokeBorder(Theme.stroke, lineWidth: 1))
    }
}
