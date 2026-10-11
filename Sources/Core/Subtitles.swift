import Foundation

struct Cue {
    let start: Double
    let end: Double
    let text: String
}

enum Subtitles {
    private static func seconds(_ ts: String) -> Double {
        let parts = ts.trimmed.replacingOccurrences(of: ",", with: ".").components(separatedBy: ".")
        let hmsPart = parts[0].split(separator: ":").map { Double($0) ?? 0 }
        let secs = hmsPart.reduce(0) { $0 * 60 + $1 }
        let frac = parts.count > 1 ? (Double("0.\(parts[1])") ?? 0) : 0
        return secs + frac
    }

    /// Parses WebVTT and SRT alike: both are blocks of "start --> end" followed by text lines.
    static func parse(_ raw: String) -> [Cue] {
        let cleaned = raw.replacingOccurrences(of: "\r", with: "").replacingOccurrences(of: "\u{FEFF}", with: "")
        var cues: [Cue] = []
        for block in cleaned.components(separatedBy: "\n\n") {
            let lines = block.components(separatedBy: "\n")
            guard let at = lines.firstIndex(where: { $0.contains("-->") }) else { continue }
            let sides = lines[at].components(separatedBy: "-->")
            guard sides.count == 2, let endToken = sides[1].trimmed.split(separator: " ").first else { continue }
            let text = lines[(at + 1)...]
                .joined(separator: "\n")
                .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                .trimmed
            if !text.isEmpty { cues.append(Cue(start: seconds(sides[0]), end: seconds(String(endToken)), text: text)) }
        }
        return cues.sorted { $0.start < $1.start }
    }

    static func load(_ url: URL) async throws -> [Cue] {
        let (data, response) = try await URLSession.shared.data(from: url)
        let text = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 200
        if status >= 400 || text.trimmed.hasPrefix("<") { throw APIError(kind: .network, message: "subtitle \(status)") }
        return parse(text)
    }

    /// Cues are sorted; a binary search keeps per-tick lookups cheap.
    static func cue(at t: Double, in cues: [Cue]) -> Cue? {
        var lo = 0, hi = cues.count - 1
        while lo <= hi {
            let mid = (lo + hi) / 2
            if cues[mid].end < t { lo = mid + 1 } else if cues[mid].start > t { hi = mid - 1 } else { return cues[mid] }
        }
        return nil
    }
}
