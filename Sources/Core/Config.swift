import Foundation

/// Identity of the official 30nama TV client (tv.30app.store). Values can rotate; keep them here.
enum Config {
    static let apiBase = "https://world.hana-api.com/api/v2/action/"
    static let clientVersion = "1.2.0"
    static let language = "fa"

    static let qrPollSeconds: UInt64 = 5
    static let qrTTLSeconds: TimeInterval = 180
    static let observerEveryS: Double = 30

    private static let keyDefaults = "30nama.apiKey"

    /// The client key is never committed. A build takes it from API_KEY in Config/Secrets.xcconfig
    /// (it lands in Info.plist); otherwise the one typed in on the TV is used.
    static var apiKey: String {
        let bundled = (Bundle.main.object(forInfoDictionaryKey: "APIKey") as? String)?.trimmed ?? ""
        if !bundled.isEmpty && !bundled.hasPrefix("$(") { return bundled }
        return UserDefaults.standard.string(forKey: keyDefaults)?.trimmed ?? ""
    }

    static func saveAPIKey(_ key: String) {
        UserDefaults.standard.set(key.trimmed, forKey: keyDefaults)
    }
}
