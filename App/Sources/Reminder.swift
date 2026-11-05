import Foundation
import UserNotifications

/// 毎日のおしらせ（端末の中だけの通知。サーバーは使わない）
enum ReminderStatus: Equatable, Sendable {
    case notDetermined
    case allowed
    case denied
}

@MainActor
@Observable
final class Reminder {
    nonisolated static let identifier = "daily.today-cards"
    private(set) var status: ReminderStatus = .notDetermined

    func refresh() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let value: ReminderStatus = switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral: .allowed
            case .denied: .denied
            default: .notDetermined
            }
            Task { @MainActor in self.status = value }
        }
    }

    /// 許可を聞いて、毎日 hour 時に通知を置く。許可されなければ false
    func enable(hour: Int) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            Task { @MainActor in
                self.status = granted ? .allowed : .denied
                if granted { Self.schedule(hour: hour) }
            }
        }
    }

    func disable() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.identifier])
    }

    nonisolated static func schedule(hour: Int) {
        let content = UNMutableNotificationContent()
        content.title = "今日の 3 枚が届いています"
        content.body = "リングをめくって、シートで 1 枚ずつ。1 分で終わります。"
        content.sound = .default
        var date = DateComponents()
        date.hour = min(max(hour, 0), 23)
        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}
