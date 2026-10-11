import Foundation

/// Tolerant JSON accessor. The 30nama API is loosely typed (numbers arrive as strings, objects
/// as arrays when empty), so models are read through this instead of strict Codable.
struct J {
    let raw: Any?
    init(_ raw: Any?) { self.raw = raw }

    subscript(key: String) -> J { J((raw as? [String: Any])?[key]) }

    var array: [J] { (raw as? [Any])?.map { J($0) } ?? [] }

    var string: String? {
        if let s = raw as? String { return s }
        if let n = raw as? NSNumber { return n.stringValue }
        return nil
    }

    var int: Int? {
        if let n = raw as? NSNumber { return n.intValue }
        if let s = raw as? String { return Int(s) ?? Double(s).map { Int($0) } }
        return nil
    }

    var double: Double? {
        if let n = raw as? NSNumber { return n.doubleValue }
        if let s = raw as? String { return Double(s) }
        return nil
    }

    var bool: Bool? {
        if let n = raw as? NSNumber { return n.boolValue }
        if let s = raw as? String { return ["true", "1"].contains(s.lowercased()) }
        return nil
    }

    var url: URL? {
        guard let s = string, !s.isEmpty else { return nil }
        return URL(string: s)
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
