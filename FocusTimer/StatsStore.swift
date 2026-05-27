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

    func recordSession(durationMinutes: Int) {
        var record = records[todayKey] ?? DayRecord()
        record.sessions += 1
        record.focusMinutes += durationMinutes
        records[todayKey] = record
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
