import Foundation
import Combine

enum SessionType: String, CaseIterable {
    case work = "Work"
    case shortBreak = "Short Break"
    case longBreak = "Long Break"

    var sfSymbol: String {
        switch self {
        case .work: return "timer"
        case .shortBreak: return "cup.and.saucer"
        case .longBreak: return "leaf"
        }
    }
}

final class TimerViewModel: ObservableObject {
    @Published var timeRemaining: Int
    @Published var sessionStartDuration: Int
    @Published var isRunning = false
    @Published var sessionType: SessionType = .work
    @Published var completedPomodoros = 0

    @Published var workDuration: Int {
        didSet { UserDefaults.standard.set(workDuration, forKey: "workDuration") }
    }
    @Published var shortBreakDuration: Int {
        didSet { UserDefaults.standard.set(shortBreakDuration, forKey: "shortBreakDuration") }
    }
    @Published var longBreakDuration: Int {
        didSet { UserDefaults.standard.set(longBreakDuration, forKey: "longBreakDuration") }
    }
    @Published var sessionsBeforeLongBreak: Int {
        didSet { UserDefaults.standard.set(sessionsBeforeLongBreak, forKey: "sessionsBeforeLongBreak") }
    }
    @Published var notificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled") }
    }
    @Published var dailyGoal: Int {
        didSet { UserDefaults.standard.set(dailyGoal, forKey: "dailyGoal") }
    }

    private var timerCancellable: AnyCancellable?

    init() {
        let ud = UserDefaults.standard

        let work = ud.integer(forKey: "workDuration")
        let short = ud.integer(forKey: "shortBreakDuration")
        let long = ud.integer(forKey: "longBreakDuration")
        let sessions = ud.integer(forKey: "sessionsBeforeLongBreak")

        workDuration = work > 0 ? work : 25
        shortBreakDuration = short > 0 ? short : 5
        longBreakDuration = long > 0 ? long : 15
        sessionsBeforeLongBreak = sessions > 0 ? sessions : 4
        notificationsEnabled = ud.object(forKey: "notificationsEnabled") as? Bool ?? true
        let goal = ud.integer(forKey: "dailyGoal")
        dailyGoal = goal > 0 ? goal : 8

        let duration = (work > 0 ? work : 25) * 60
        timeRemaining = duration
        sessionStartDuration = duration
        completedPomodoros = StatsStore.shared.todaySessions
    }

    var progress: Double {
        guard sessionStartDuration > 0 else { return 0 }
        return Double(sessionStartDuration - timeRemaining) / Double(sessionStartDuration)
    }

    var formattedTime: String {
        String(format: "%02d:%02d", timeRemaining / 60, timeRemaining % 60)
    }

    func toggleTimer() {
        isRunning ? pause() : start()
    }

    func start() {
        isRunning = true
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }

    func pause() {
        isRunning = false
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    func reset() {
        pause()
        let duration = durationFor(sessionType)
        timeRemaining = duration
        sessionStartDuration = duration
    }

    func skip() {
        pause()
        advance()
    }

    private func tick() {
        guard timeRemaining > 0 else {
            sessionComplete()
            return
        }
        timeRemaining -= 1
    }

    private func sessionComplete() {
        pause()

        if notificationsEnabled {
            NotificationManager.shared.notify(sessionEnded: sessionType)
        }

        if sessionType == .work {
            completedPomodoros += 1
            StatsStore.shared.recordSession(durationMinutes: workDuration)
            syncStats()
        }

        advance()
        start()
    }

    private func syncStats() {
        let sessions = StatsStore.shared.todaySessions
        let minutes  = StatsStore.shared.todayFocusMinutes
        let streak   = StatsStore.shared.currentStreak
        Task {
            guard SupabaseConfig.isConfigured else { return }
            try? await SupabaseManager.shared.ensureAuthenticated()
            try? await SupabaseManager.shared.upsertTodayStats(
                sessions: sessions,
                focusMinutes: minutes,
                streak: streak
            )
        }
    }

    private func advance() {
        switch sessionType {
        case .work:
            let isLongBreak = completedPomodoros > 0 && completedPomodoros % sessionsBeforeLongBreak == 0
            sessionType = isLongBreak ? .longBreak : .shortBreak
        case .shortBreak, .longBreak:
            sessionType = .work
        }
        let duration = durationFor(sessionType)
        timeRemaining = duration
        sessionStartDuration = duration
    }

    private func durationFor(_ type: SessionType) -> Int {
        switch type {
        case .work: return workDuration * 60
        case .shortBreak: return shortBreakDuration * 60
        case .longBreak: return longBreakDuration * 60
        }
    }
}
