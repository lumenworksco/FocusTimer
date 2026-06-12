import AppKit
import Foundation
import UserNotifications

enum NotificationSound: String, CaseIterable {
    case systemDefault = "Default"
    case glass         = "Glass"
    case ping          = "Ping"
    case none          = "None"

    // Used for the preview speaker button in Settings (only Glass/Ping support preview).
    func preview() {
        switch self {
        case .glass: NSSound(named: NSSound.Name("Glass"))?.play()
        case .ping:  NSSound(named: NSSound.Name("Ping"))?.play()
        case .systemDefault, .none: break
        }
    }

    var canPreview: Bool {
        self == .glass || self == .ping
    }

    // Notification sound: named sounds play via NSSound at session-complete,
    // so the notification itself carries no sound (avoids double-play).
    var unSound: UNNotificationSound? {
        switch self {
        case .systemDefault: return .default
        case .glass, .ping, .none: return nil
        }
    }

    // Plays the NSSound variant at session-complete (no-op for Default/None).
    func playAtSessionEnd() {
        switch self {
        case .glass: NSSound(named: NSSound.Name("Glass"))?.play()
        case .ping:  NSSound(named: NSSound.Name("Ping"))?.play()
        case .systemDefault, .none: break
        }
    }
}

final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func notify(sessionEnded type: SessionType, sound: UNNotificationSound?, taskLabel: String = "") {
        let content = UNMutableNotificationContent()

        switch type {
        case .work:
            content.title = "Work session complete!"
            content.body  = taskLabel.isEmpty
                ? "Time to take a break. Great focus session."
                : "\(taskLabel) — take a well-earned break."
        case .shortBreak:
            content.title = "Break over!"
            content.body = "Ready to get back to it?"
        case .longBreak:
            content.title = "Long break over!"
            content.body = "Fully recharged? Let\u{2019}s go."
        }

        content.sound = sound

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    func sendWeeklyDigest(sessions: Int, minutes: Int, streak: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Weekly focus summary"
        if sessions == 0 {
            content.body = "No sessions this week — ready to start fresh?"
        } else {
            var parts: [String] = ["\(sessions) session\(sessions == 1 ? "" : "s")"]
            if minutes >= 60 {
                let h = minutes / 60, m = minutes % 60
                parts.append(m == 0 ? "\(h)h" : "\(h)h \(m)m")
            } else if minutes > 0 {
                parts.append("\(minutes)m")
            }
            if streak > 1 { parts.append("\(streak)-day streak") }
            content.body = parts.joined(separator: " · ")
        }
        content.sound = .default
        let request = UNNotificationRequest(identifier: "weekly-digest-\(UUID())", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
