import Foundation

enum SubLang: String, CaseIterable {
    case fa, en, off
    var label: String {
        switch self {
        case .fa: return tr("فارسی")
        case .en: return tr("انگلیسی")
        case .off: return tr("خاموش")
        }
    }
}

enum SubSize: String, CaseIterable {
    case s, m, l
    var label: String {
        switch self {
        case .s: return tr("کوچک")
        case .m: return tr("متوسط")
        case .l: return tr("بزرگ")
        }
    }
    var pointSize: CGFloat {
        #if os(tvOS)
        switch self {
        case .s: return 38
        case .m: return 48
        case .l: return 60
        }
        #else
        switch self {
        case .s: return 15
        case .m: return 19
        case .l: return 24
        }
        #endif
    }
}

enum AudioPref: String, CaseIterable {
    case stereo = "2"
    case surround = "6"
    var label: String { self == .stereo ? tr("استریو (۲ کاناله)") : tr("فراگیر ۵.۱ (۶ کاناله)") }
}

/// Highest video height to play at; 0 = automatic.
enum Quality: Int, CaseIterable {
    case auto = 0, p1080 = 1080, p720 = 720, p480 = 480
    var label: String { self == .auto ? tr("خودکار") : "\(rawValue)p" }
}

/// Viewer preferences, kept on the device in UserDefaults.
@MainActor
final class SettingsStore: ObservableObject {
    private let d = UserDefaults.standard

    @Published var language: AppLanguage {
        didSet { d.set(language.rawValue, forKey: "30nama.language"); Lang.current = language }
    }
    @Published var subLang: SubLang { didSet { d.set(subLang.rawValue, forKey: "30nama.subLang") } }
    @Published var subSize: SubSize { didSet { d.set(subSize.rawValue, forKey: "30nama.subSize") } }
    @Published var audio: AudioPref { didSet { d.set(audio.rawValue, forKey: "30nama.audio") } }
    @Published var quality: Quality { didSet { d.set(quality.rawValue, forKey: "30nama.quality") } }

    init() {
        let lang = AppLanguage(rawValue: d.string(forKey: "30nama.language") ?? "") ?? .deviceDefault
        Lang.current = lang
        language = lang
        subLang = SubLang(rawValue: d.string(forKey: "30nama.subLang") ?? "") ?? .fa
        subSize = SubSize(rawValue: d.string(forKey: "30nama.subSize") ?? "") ?? .m
        audio = AudioPref(rawValue: d.string(forKey: "30nama.audio") ?? "") ?? .stereo
        quality = Quality(rawValue: d.integer(forKey: "30nama.quality")) ?? .auto
    }
}
