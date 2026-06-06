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

    func notify(sessionEnded type: SessionType, sound: UNNotificationSound?) {
        let content = UNMutableNotificationContent()

        switch type {
        case .work:
            content.title = "Work session complete!"
            content.body = "Time to take a break. Great focus session."
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
}
