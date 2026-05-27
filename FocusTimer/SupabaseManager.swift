import Foundation

actor SupabaseManager {
    static let shared = SupabaseManager()

    private let baseURL: String
    private let anon: String
    private var token: String?
    private var uid: String?

    private init() {
        baseURL = SupabaseConfig.projectURL
        anon    = SupabaseConfig.anonKey
        token   = UserDefaults.standard.string(forKey: "_sb_tok")
        uid     = UserDefaults.standard.string(forKey: "_sb_uid")
    }

    var currentUserId: String? { uid }

    // MARK: - Auth

    func ensureAuthenticated() async throws {
        if token != nil, uid != nil { return }
        do    { try await signIn()  }
        catch { try await signUp()  }
    }

    private func signUp() async throws {
        let body: [String: Any] = ["email": deviceEmail, "password": deviceId]
        let r = try await authPost("/auth/v1/signup", body: body)
        guard let tok = r["access_token"] as? String,
              let u   = (r["user"] as? [String: Any])?["id"] as? String
        else { throw SupabaseError.authFailed }
        store(token: tok, uid: u)
    }

    private func signIn() async throws {
        let body: [String: Any] = ["email": deviceEmail, "password": deviceId]
        let r = try await authPost("/auth/v1/token?grant_type=password", body: body)
        guard let tok = r["access_token"] as? String,
              let u   = (r["user"] as? [String: Any])?["id"] as? String
        else { throw SupabaseError.authFailed }
        store(token: tok, uid: u)
    }

    private func reAuth() async throws {
        token = nil; uid = nil
        try await signIn()
    }

    private var deviceId: String {
        if let id = UserDefaults.standard.string(forKey: "_sb_dev") { return id }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: "_sb_dev")
        return id
    }

    private var deviceEmail: String {
        let safe = deviceId.prefix(16).lowercased().filter(\.isHexDigit)
        return "d\(safe)@focustimer.local"
    }

    private func store(token t: String, uid u: String) {
        token = t; uid = u
        UserDefaults.standard.set(t, forKey: "_sb_tok")
        UserDefaults.standard.set(u, forKey: "_sb_uid")
    }

    // MARK: - Profile

    func getMyProfile() async throws -> Profile? {
        guard let id = uid else { return nil }
        let rows = try await get("/rest/v1/profiles", query: ["id": "eq.\(id)", "select": "*"])
        return rows.first.flatMap(decodeProfile)
    }

    func createProfile(username: String) async throws {
        guard let id = uid else { throw SupabaseError.notAuthenticated }
        try await post("/rest/v1/profiles", body: ["id": id, "username": username])
    }

    func searchProfile(username: String) async throws -> Profile? {
        let rows = try await get("/rest/v1/profiles", query: ["username": "eq.\(username)", "select": "*"])
        return rows.first.flatMap(decodeProfile)
    }

    // MARK: - Friends

    func addFriend(friendId: String) async throws {
        guard let id = uid else { throw SupabaseError.notAuthenticated }
        try await post("/rest/v1/friendships", body: ["user_id": id, "friend_id": friendId])
    }

    func removeFriend(friendId: String) async throws {
        guard let id = uid else { throw SupabaseError.notAuthenticated }
        try await delete("/rest/v1/friendships", query: [
            "user_id": "eq.\(id)", "friend_id": "eq.\(friendId)"
        ])
    }

    func getFriendIds() async throws -> [String] {
        guard let id = uid else { return [] }
        let rows = try await get("/rest/v1/friendships", query: [
            "user_id": "eq.\(id)", "select": "friend_id"
        ])
        return rows.compactMap { $0["friend_id"] as? String }
    }

    func getProfiles(ids: [String]) async throws -> [Profile] {
        guard !ids.isEmpty else { return [] }
        let list = ids.joined(separator: ",")
        let rows = try await get("/rest/v1/profiles", query: ["id": "in.(\(list))", "select": "*"])
        return rows.compactMap(decodeProfile)
    }

    // MARK: - Stats

    func upsertTodayStats(sessions: Int, focusMinutes: Int, streak: Int) async throws {
        guard let id = uid else { throw SupabaseError.notAuthenticated }
        let today = DateFormatter.yyyyMMdd.string(from: Date())
        try await upsert("/rest/v1/daily_stats", body: [
            "user_id": id, "date": today,
            "sessions": sessions, "focus_minutes": focusMinutes, "streak": streak
        ])
    }

    func getStatsForUsers(ids: [String], since date: String) async throws -> [DailyStat] {
        guard !ids.isEmpty else { return [] }
        let list = ids.joined(separator: ",")
        let rows = try await get("/rest/v1/daily_stats", query: [
            "user_id": "in.(\(list))", "date": "gte.\(date)", "select": "*"
        ])
        return rows.compactMap(decodeStat)
    }

    // MARK: - HTTP

    private func get(_ path: String, query: [String: String]) async throws -> [[String: Any]] {
        var comps = URLComponents(string: baseURL + path)!
        comps.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "GET"
        setBaseHeaders(&req)
        let (data, resp) = try await URLSession.shared.data(for: req)
        if (resp as? HTTPURLResponse)?.statusCode == 401 {
            try await reAuth()
            return try await get(path, query: query)
        }
        return (try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]) ?? []
    }

    private func post(_ path: String, body: [String: Any]) async throws {
        var req = URLRequest(url: URL(string: baseURL + path)!)
        req.httpMethod = "POST"
        setBaseHeaders(&req)
        req.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        let (_, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        if code == 401 { try await reAuth(); try await post(path, body: body) }
        else if code == 409 { throw SupabaseError.conflict }
    }

    private func upsert(_ path: String, body: [String: Any]) async throws {
        var req = URLRequest(url: URL(string: baseURL + path)!)
        req.httpMethod = "POST"
        setBaseHeaders(&req)
        req.setValue("resolution=merge-duplicates,return=minimal", forHTTPHeaderField: "Prefer")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        let (_, resp) = try await URLSession.shared.data(for: req)
        if (resp as? HTTPURLResponse)?.statusCode == 401 {
            try await reAuth()
            try await upsert(path, body: body)
        }
    }

    private func delete(_ path: String, query: [String: String]) async throws {
        var comps = URLComponents(string: baseURL + path)!
        comps.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "DELETE"
        setBaseHeaders(&req)
        let (_, resp) = try await URLSession.shared.data(for: req)
        if (resp as? HTTPURLResponse)?.statusCode == 401 {
            try await reAuth()
            try await delete(path, query: query)
        }
    }

    private func authPost(_ path: String, body: [String: Any]) async throws -> [String: Any] {
        var req = URLRequest(url: URL(string: baseURL + path)!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(anon, forHTTPHeaderField: "apikey")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await URLSession.shared.data(for: req)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SupabaseError.decodingError
        }
        if let msg = json["error_description"] as? String { throw SupabaseError.serverError(msg) }
        if let msg = json["msg"] as? String, json["access_token"] == nil { throw SupabaseError.serverError(msg) }
        return json
    }

    private func setBaseHeaders(_ req: inout URLRequest) {
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(anon, forHTTPHeaderField: "apikey")
        if let t = token { req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization") }
    }

    // MARK: - Decode

    private func decodeProfile(_ dict: [String: Any]) -> Profile? {
        guard let id       = dict["id"] as? String,
              let username = dict["username"] as? String else { return nil }
        return Profile(id: id, username: username)
    }

    private func decodeStat(_ dict: [String: Any]) -> DailyStat? {
        guard let data = try? JSONSerialization.data(withJSONObject: dict) else { return nil }
        return try? JSONDecoder().decode(DailyStat.self, from: data)
    }
}

enum SupabaseError: LocalizedError {
    case authFailed, notAuthenticated, conflict, decodingError, serverError(String)

    var errorDescription: String? {
        switch self {
        case .authFailed:          return "Sign-in failed. Check your Supabase config and make sure email confirmation is disabled."
        case .notAuthenticated:    return "Not signed in."
        case .conflict:            return "Username already taken."
        case .decodingError:       return "Unexpected server response."
        case .serverError(let m):  return m
        }
    }
}
