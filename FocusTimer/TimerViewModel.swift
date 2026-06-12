import Foundation
import Combine
import CoreGraphics
import ServiceManagement

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
    @Published var autoAdvance: Bool {
        didSet { UserDefaults.standard.set(autoAdvance, forKey: "autoAdvance") }
    }
    @Published var showTaskLabelInMenuBar: Bool {
        didSet { UserDefaults.standard.set(showTaskLabelInMenuBar, forKey: "showTaskLabelInMenuBar") }
    }
    @Published var hotkeysEnabled: Bool {
        didSet {
            UserDefaults.standard.set(hotkeysEnabled, forKey: "hotkeysEnabled")
            if hotkeysEnabled { HotkeyManager.shared.register() } else { HotkeyManager.shared.unregister() }
        }
    }
    @Published var notificationSound: NotificationSound {
        didSet { UserDefaults.standard.set(notificationSound.rawValue, forKey: "notificationSound") }
    }
    @Published var launchAtLogin: Bool {
        didSet {
            if launchAtLogin { try? SMAppService.mainApp.register() }
            else             { try? SMAppService.mainApp.unregister() }
        }
    }
    @Published var idleDetectionEnabled: Bool {
        didSet {
            UserDefaults.standard.set(idleDetectionEnabled, forKey: "idleDetectionEnabled")
            if idleDetectionEnabled { if isRunning { startIdleMonitor() } }
            else { stopIdleMonitor() }
        }
    }
    @Published var idlePauseThreshold: Int {
        didSet { UserDefaults.standard.set(idlePauseThreshold, forKey: "idlePauseThreshold") }
    }
    @Published var toggleHotkeyLabel: String
    @Published var skipHotkeyLabel: String
    @Published var taskLabel: String {
        didSet { UserDefaults.standard.set(taskLabel, forKey: "taskLabel") }
    }

    private var timerCancellable: AnyCancellable?
    private var idleMonitorCancellable: AnyCancellable?
    private var pausedDueToIdle = false

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
        autoAdvance = ud.object(forKey: "autoAdvance") as? Bool ?? true
        showTaskLabelInMenuBar = ud.object(forKey: "showTaskLabelInMenuBar") as? Bool ?? false
        hotkeysEnabled = ud.object(forKey: "hotkeysEnabled") as? Bool ?? true
        let soundRaw = ud.string(forKey: "notificationSound") ?? NotificationSound.systemDefault.rawValue
        notificationSound = NotificationSound(rawValue: soundRaw) ?? .systemDefault
        launchAtLogin = SMAppService.mainApp.status == .enabled
        idleDetectionEnabled = ud.object(forKey: "idleDetectionEnabled") as? Bool ?? true
        let idleThresh = ud.integer(forKey: "idlePauseThreshold")
        idlePauseThreshold = idleThresh > 0 ? idleThresh : 5
        toggleHotkeyLabel = ud.string(forKey: "toggleHotkeyLabel") ?? "⌃⌥Space"
        skipHotkeyLabel   = ud.string(forKey: "skipHotkeyLabel")   ?? "⌃⌥S"
        taskLabel         = ud.string(forKey: "taskLabel")         ?? ""

        let duration = (work > 0 ? work : 25) * 60
        timeRemaining = duration
        sessionStartDuration = duration
        completedPomodoros = StatsStore.shared.todaySessions
    }

    func updateToggleHotkey(code: Int, mods: Int, label: String) {
        let ud = UserDefaults.standard
        let skipCode = ud.object(forKey: "skipHotkeyCode") as? Int ?? 1
        let skipMods = ud.object(forKey: "skipHotkeyMods") as? Int ?? 6144
        guard code != skipCode || mods != skipMods else {
            if hotkeysEnabled { HotkeyManager.shared.register() }
            return
        }
        ud.set(code, forKey: "toggleHotkeyCode")
        ud.set(mods, forKey: "toggleHotkeyMods")
        ud.set(label, forKey: "toggleHotkeyLabel")
        toggleHotkeyLabel = label
        if hotkeysEnabled { HotkeyManager.shared.register() }
    }

    func updateSkipHotkey(code: Int, mods: Int, label: String) {
        let ud = UserDefaults.standard
        let toggleCode = ud.object(forKey: "toggleHotkeyCode") as? Int ?? 49
        let toggleMods = ud.object(forKey: "toggleHotkeyMods") as? Int ?? 6144
        guard code != toggleCode || mods != toggleMods else {
            if hotkeysEnabled { HotkeyManager.shared.register() }
            return
        }
        ud.set(code, forKey: "skipHotkeyCode")
        ud.set(mods, forKey: "skipHotkeyMods")
        ud.set(label, forKey: "skipHotkeyLabel")
        skipHotkeyLabel = label
        if hotkeysEnabled { HotkeyManager.shared.register() }
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
        pausedDueToIdle = false
        isRunning = true
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
        if idleDetectionEnabled { startIdleMonitor() }
    }

    func pause() {
        isRunning = false
        timerCancellable?.cancel()
        timerCancellable = nil
        stopIdleMonitor()
    }

    private func pauseForIdle() {
        isRunning = false
        timerCancellable?.cancel()
        timerCancellable = nil
        // Idle monitor stays running to detect when user returns
    }

    private func startIdleMonitor() {
        idleMonitorCancellable?.cancel()
        idleMonitorCancellable = Timer.publish(every: 5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.checkIdle() }
    }

    private func stopIdleMonitor() {
        idleMonitorCancellable?.cancel()
        idleMonitorCancellable = nil
        pausedDueToIdle = false
    }

    private func checkIdle() {
        let mouseIdle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .mouseMoved)
        let keyIdle   = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown)
        let idleSecs  = min(mouseIdle, keyIdle)

        if pausedDueToIdle {
            if idleSecs < 5.0 { start() } // user returned — auto-resume
        } else if isRunning, idleSecs >= Double(idlePauseThreshold * 60) {
            pausedDueToIdle = true
            pauseForIdle()
        }
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
        if autoAdvance { start() }
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
            notificationSound.playAtSessionEnd()
            NotificationManager.shared.notify(sessionEnded: sessionType, sound: notificationSound.unSound, taskLabel: taskLabel)
        }

        if sessionType == .work {
            completedPomodoros += 1
            StatsStore.shared.recordSession(durationMinutes: workDuration)
            syncStats()
        }

        advance()
        if autoAdvance { start() }
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
