import Foundation
import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func notify(sessionEnded type: SessionType) {
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

        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}
