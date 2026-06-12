import Foundation

private struct DayRecord: Codable {
    var sessions: Int = 0
    var focusMinutes: Int = 0
}

final class StatsStore {
    static let shared = StatsStore()

    private let udKey = "v1_daily_stats"
    private var records: [String: DayRecord]

    private init() {
        if let data = UserDefaults.standard.data(forKey: udKey),
           let decoded = try? JSONDecoder().decode([String: DayRecord].self, from: data) {
            records = decoded
        } else {
            records = [:]
        }
        let logData = UserDefaults.standard.data(forKey: "v1_session_log")
        if let data = logData,
           let decoded = try? JSONDecoder().decode([SessionEntry].self, from: data) {
            sessionLog = decoded
        } else {
            sessionLog = []
        }
    }

    var todaySessions: Int     { records[todayKey]?.sessions     ?? 0 }
    var todayFocusMinutes: Int { records[todayKey]?.focusMinutes ?? 0 }

    var weekSessions: Int {
        let cal = Calendar.current
        return (0..<7).reduce(0) { sum, i in
            guard let d = cal.date(byAdding: .day, value: -i, to: Date()) else { return sum }
            return sum + (records[key(for: d)]?.sessions ?? 0)
        }
    }

    var currentStreak: Int {
        let cal = Calendar.current
        var streak = 0
        var date = Date()

        if todaySessions > 0 {
            streak = 1
            date = cal.date(byAdding: .day, value: -1, to: date) ?? date
        } else {
            guard let prev = cal.date(byAdding: .day, value: -1, to: date) else { return 0 }
            date = prev
            guard (records[key(for: date)]?.sessions ?? 0) > 0 else { return 0 }
            streak = 1
            date = cal.date(byAdding: .day, value: -1, to: date) ?? date
        }

        while true {
            guard (records[key(for: date)]?.sessions ?? 0) > 0,
                  let prev = cal.date(byAdding: .day, value: -1, to: date) else { break }
            streak += 1
            date = prev
        }
        return streak
    }

    struct DayStat {
        let date: Date
        let sessions: Int
        let focusMinutes: Int
        var isToday: Bool { Calendar.current.isDateInToday(date) }
    }

    func history(days n: Int) -> [DayStat] {
        let cal = Calendar.current
        return (0..<n).compactMap { i -> DayStat? in
            guard let d = cal.date(byAdding: .day, value: -(n - 1 - i), to: Date()) else { return nil }
            let r = records[key(for: d)] ?? DayRecord()
            return DayStat(date: d, sessions: r.sessions, focusMinutes: r.focusMinutes)
        }
    }

    // MARK: - Session log

    struct SessionEntry: Codable, Identifiable {
        var id: UUID = UUID()
        let timestamp: Date
        let durationMinutes: Int
        let taskLabel: String
    }

    private let logKey = "v1_session_log"
    private(set) var sessionLog: [SessionEntry]

    func recentEntries(days: Int) -> [SessionEntry] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return sessionLog.filter { $0.timestamp >= cutoff }
    }

    // MARK: - Record

    func recordSession(durationMinutes: Int, taskLabel: String = "") {
        var record = records[todayKey] ?? DayRecord()
        record.sessions += 1
        record.focusMinutes += durationMinutes
        records[todayKey] = record

        let entry = SessionEntry(timestamp: Date(), durationMinutes: durationMinutes, taskLabel: taskLabel)
        sessionLog.append(entry)
        if sessionLog.count > 500 { sessionLog.removeFirst(sessionLog.count - 500) }
        persistLog()

        persist()
    }

    private var todayKey: String { key(for: Date()) }

    private func key(for date: Date) -> String {
        DateFormatter.yyyyMMdd.string(from: date)
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: udKey)
        }
    }

    private func persistLog() {
        if let data = try? JSONEncoder().encode(sessionLog) {
            UserDefaults.standard.set(data, forKey: logKey)
        }
    }
}

extension DateFormatter {
    static let yyyyMMdd: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        return f
    }()
}
