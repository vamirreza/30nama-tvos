import SwiftUI
import UIKit

/// Vazirmatn (SIL OFL, see Resources/Fonts/OFL.txt) is bundled so Persian text looks the same on
/// every Apple TV. Falls back to the system font if the files are missing from the bundle.
enum Vazir {
    static func name(_ weight: Font.Weight) -> String {
        switch weight {
        case .ultraLight, .thin, .light, .regular: return "Vazirmatn-Regular"
        case .medium: return "Vazirmatn-Medium"
        case .semibold: return "Vazirmatn-SemiBold"
        case .bold: return "Vazirmatn-Bold"
        default: return "Vazirmatn-ExtraBold"
        }
    }

    static func uiFont(_ size: CGFloat, _ weight: Font.Weight = .regular) -> UIFont {
        UIFont(name: name(weight), size: size) ?? .systemFont(ofSize: size, weight: weight.uiWeight)
    }
}

extension Font.Weight {
    var uiWeight: UIFont.Weight {
        switch self {
        case .ultraLight: return .ultraLight
        case .thin: return .thin
        case .light: return .light
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        case .black: return .black
        default: return .regular
        }
    }
}

extension Font {
    /// A Vazirmatn font at a fixed point size (tvOS has no Dynamic Type to scale it).
    static func vazir(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom(Vazir.name(weight), fixedSize: size)
    }

    private static func sized(tv: CGFloat, phone: CGFloat) -> CGFloat {
        #if os(tvOS)
        tv
        #else
        phone
        #endif
    }

    static let appLargeTitle = vazir(sized(tv: 76, phone: 30), .bold)
    static let appTitle = vazir(sized(tv: 64, phone: 26), .bold)
    static let appTitle2 = vazir(sized(tv: 52, phone: 21), .bold)
    static let appTitle3 = vazir(sized(tv: 42, phone: 17))
    static let appTitle3Bold = vazir(sized(tv: 42, phone: 17), .bold)
    static let appHeadline = vazir(sized(tv: 36, phone: 15), .semibold)
    static let appCallout = vazir(sized(tv: 30, phone: 14))
    static let appCalloutMedium = vazir(sized(tv: 30, phone: 14), .medium)
    static let appBody = vazir(sized(tv: 29, phone: 15))
    static let appCaption = vazir(sized(tv: 24, phone: 12))
    static let appCaption2Bold = vazir(sized(tv: 22, phone: 11), .bold)
    static let appTitleLarge = vazir(sized(tv: 56, phone: 24), .bold)
    /// The wordmark on the sign-in screen.
    static let appBrand = vazir(sized(tv: 80, phone: 44), .heavy)
}
