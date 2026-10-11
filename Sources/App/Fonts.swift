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
    /// tvOS text-style sizes, set in Vazirmatn.
    static func vazir(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom(Vazir.name(weight), fixedSize: size)
    }

    static let appLargeTitle = vazir(76, .bold)
    static let appTitle = vazir(64, .bold)
    static let appTitle2 = vazir(52, .bold)
    static let appTitle3 = vazir(42)
    static let appTitle3Bold = vazir(42, .bold)
    static let appHeadline = vazir(36, .semibold)
    static let appCallout = vazir(30)
    static let appCalloutMedium = vazir(30, .medium)
    static let appBody = vazir(29)
    static let appCaption = vazir(24)
    static let appCaption2Bold = vazir(22, .bold)
}
