import Foundation

final class DigestChecker {
    static let shared = DigestChecker()
    private var timer: Timer?
    private init() {}

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { [weak self] _ in
            self?.check()
        }
        check()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func check() {
        let cal = Calendar.current
        let now = Date()
        guard cal.component(.weekday, from: now) == 1,  // Sunday
              cal.component(.hour,    from: now) == 20  // 8 pm
        else { return }

        // Send at most once per calendar week
        let thisWeek = cal.component(.weekOfYear, from: now)
        let lastWeek = UserDefaults.standard.integer(forKey: "lastDigestWeek")
        guard thisWeek != lastWeek else { return }

        let data     = StatsStore.shared.history(days: 7)
        let sessions = data.reduce(0) { $0 + $1.sessions }
        let minutes  = data.reduce(0) { $0 + $1.focusMinutes }
        let streak   = StatsStore.shared.currentStreak

        NotificationManager.shared.sendWeeklyDigest(sessions: sessions, minutes: minutes, streak: streak)
        UserDefaults.standard.set(thisWeek, forKey: "lastDigestWeek")
    }
}
