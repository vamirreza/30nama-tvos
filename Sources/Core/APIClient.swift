import Foundation

enum APIErrorKind { case challenge, unauthorized, rejected, network }

struct APIError: LocalizedError {
    let kind: APIErrorKind
    let message: String
    var status: Int?
    var errorDescription: String? { message }
}

struct Envelope {
    let status: Int
    let success: Bool
    let msg: String?
    let result: J
}

/// Human-readable text for an error, or nil when it only means "the view went away".
func describe(_ error: Error) -> String? {
    if error is CancellationError { return nil }
    if let e = error as? URLError, e.code == .cancelled { return nil }
    return (error as? APIError)?.message ?? error.localizedDescription
}

/// v2 actions are form-encoded POSTs with the official client's headers.
enum Client {
    private static let session: URLSession = {
        let c = URLSessionConfiguration.default
        c.timeoutIntervalForRequest = 20
        return URLSession(configuration: c)
    }()

    private static let formAllowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")

    private static func encode(_ form: [String: Any?]) -> Data {
        func enc(_ s: String) -> String { s.addingPercentEncoding(withAllowedCharacters: formAllowed) ?? s }
        var pairs: [String] = []
        for key in form.keys.sorted() {
            guard let value = form[key], let v = value else { continue }
            pairs.append("\(enc(key))=\(enc("\(v)"))")
        }
        return pairs.joined(separator: "&").data(using: .utf8) ?? Data()
    }

    static func call(_ action: String, _ form: [String: Any?] = [:], retries: Int = 2) async throws -> Envelope {
        guard let url = URL(string: Config.apiBase + action) else {
            throw APIError(kind: .network, message: "نشانی نامعتبر")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = encode(form)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.apiKey, forHTTPHeaderField: "c-api-key")
        request.setValue(Config.clientVersion, forHTTPHeaderField: "c-version-number")
        request.setValue(Config.language, forHTTPHeaderField: "c-language")
        if let token = SessionStore.token { request.setValue(token, forHTTPHeaderField: "c-token") }

        var lastError: Error?
        for attempt in 0...retries {
            do {
                let (data, response) = try await session.data(for: request)
                let http = (response as? HTTPURLResponse)?.statusCode ?? 0
                let text = String(data: data, encoding: .utf8) ?? ""
                // Fire-and-forget actions such as `observer` answer 204 with no body.
                if http == 204 || ((200..<300).contains(http) && text.trimmed.isEmpty) {
                    return Envelope(status: http, success: true, msg: nil, result: J(nil))
                }
                // Cloudflare answers blocked clients with an HTML challenge page instead of JSON.
                if text.trimmed.hasPrefix("<") {
                    throw APIError(kind: .challenge, message: "سرور سی‌نما درخواست را مسدود کرد", status: http)
                }
                guard let obj = try? JSONSerialization.jsonObject(with: data) else { throw URLError(.cannotParseResponse) }
                let j = J(obj)
                let status = j["status"].int ?? http
                if status == 401 || status == 403 || http == 401 {
                    throw APIError(kind: .unauthorized, message: j["msg"].string ?? "دسترسی ندارید", status: status)
                }
                return Envelope(status: status, success: j["success"].bool ?? false, msg: j["msg"].string, result: j["result"])
            } catch let e as APIError {
                throw e
            } catch {
                if Task.isCancelled { throw CancellationError() }
                lastError = error
                if attempt < retries { try? await Task.sleep(nanoseconds: UInt64(1_500_000_000 * (attempt + 1))) }
            }
        }
        throw APIError(kind: .network, message: lastError?.localizedDescription ?? "اتصال برقرار نشد")
    }

    /// Most screens only want the result and treat success:false as an error.
    static func result(_ action: String, _ form: [String: Any?] = [:]) async throws -> J {
        let env = try await call(action, form)
        if !env.success { throw APIError(kind: .rejected, message: env.msg ?? "خطای ناشناخته", status: env.status) }
        return env.result
    }
}
