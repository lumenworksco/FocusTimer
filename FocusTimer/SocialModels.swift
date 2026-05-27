import Foundation

struct Profile: Codable, Identifiable, Hashable {
    let id: String
    let username: String
}

struct DailyStat: Codable {
    let userId: String
    let date: String
    let sessions: Int
    let focusMinutes: Int
    let streak: Int

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case date, sessions, streak
        case focusMinutes = "focus_minutes"
    }
}

struct FriendWithStats: Identifiable {
    let profile: Profile
    let todaySessions: Int
    let todayMinutes: Int
    let weekSessions: Int

    var id: String { profile.id }
}
