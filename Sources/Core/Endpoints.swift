import Foundation

/// v2 actions, mirrored from the official TV client's SDK. The whole API surface in one place.
enum API {
    // auth
    static func qrCode() async throws -> QrCode {
        let j = try await Client.result("qrlogin_code")
        guard let code = j["code"].string, let url = j["url"].string else {
            throw APIError(kind: .rejected, message: tr("کد QR دریافت نشد"))
        }
        return QrCode(code: code, url: url)
    }

    /// The token once the code is approved, nil while pending (msg CODE_NOT_USED).
    static func qrLogin(_ code: String) async throws -> String? {
        let env = try await Client.call("qrlogin_login", ["auth_code": code], retries: 0)
        return env.result["token"].string
    }

    static func user() async throws -> User { User(try await Client.result("user")) }
    static func logout() async throws { _ = try await Client.call("logout") }

    // browse
    static func homeStream() async throws -> HomeStream { HomeStream(try await Client.result("home_stream")) }
    static func menu() async throws -> MenuData { MenuData(try await Client.result("menu")) }
    static func single(_ postId: Int) async throws -> Title {
        guard let t = Title(try await Client.result("single", ["post_id": postId])) else {
            throw APIError(kind: .rejected, message: tr("عنوان پیدا نشد"))
        }
        return t
    }

    // `streamonly` must be the string "true"; the server ignores 1 and returns unplayable titles.
    static func search(_ query: String, page: Int = 1) async throws -> Page {
        Page(try await Client.result("search", ["query": query, "streamonly": "true", "page": page]))
    }

    static func archive(_ slug: String, page: Int = 1, orderBy: String = "relevant") async throws -> Page {
        Page(try await Client.result("archive", ["slugs": slug, "streamonly": "true", "page": page, "orderby": orderBy, "order": "desc"]))
    }

    static func advancedSearchParameters() async throws -> AdvancedParameters {
        AdvancedParameters(try await Client.result("advanced_search_parameters"))
    }

    /// `parameters` is a JSON object. List fields take arrays; people (actor, director) take an
    /// IMDb id such as nm0000206.
    static func advancedSearch(_ parametersJSON: String, page: Int = 1, orderBy: String = "relevant") async throws -> Page {
        Page(try await Client.result("advanced_search", ["parameters": parametersJSON, "orderby": orderBy, "order": "desc", "page": page]))
    }

    static func notifications(page: Int = 1) async throws -> [AppNotification] {
        try await Client.result("notification", ["page": page])["notifications"].array.compactMap { AppNotification($0) }
    }

    static func readNotification(_ id: Int) async throws { _ = try await Client.call("notification_read", ["notification_id": id]) }

    // playback
    static func stream(_ postId: Int) async throws -> StreamInfo { StreamInfo(try await Client.result("stream", ["post_id": postId])) }
    static func continueWatching() async throws -> Page { Page(try await Client.result("continue_watching")) }
    static func dismissContinue(_ id: Int) async throws { _ = try await Client.call("continue_watching_dismiss", ["id": id]) }

    static func observer(postId: Int, fileId: Int, userId: Int, time: Int, duration: Int, token: String) async throws {
        _ = try await Client.call(
            "observer",
            ["post_id": postId, "file_id": fileId, "user_id": userId, "time": time, "duration": duration, "token": token],
            retries: 0
        )
    }

    // library
    static func myLists() async throws -> MyLists { MyLists(try await Client.result("user_mylist")) }

    static func list(_ group: String, page: Int = 1) async throws -> Page {
        Page(try await Client.result("user_list", ["action": "list", "group": group, "page": page, "orderby": "add_list", "order": "DESC"]))
    }

    /// `add` toggles: a second call removes the title again.
    static func toggleList(_ group: String, _ postId: Int) async throws {
        _ = try await Client.call("user_list", ["action": "add", "group": group, "post_id": postId])
    }
}
