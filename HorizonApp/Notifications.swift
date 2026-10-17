import Foundation
import HorizonCore
import UserNotifications

/// Localized content of the notifications planned by HorizonCore.
enum Notifications {
    static let category = "SOLAR_EVENT"
    static let acknowledgeAction = "ACKNOWLEDGE"
    static let eventIDKey = "eventID"
    static let bodyKey = "body"
    static let nextKey = "next"
    static let kindKey = "kind"

    static func registerCategory() {
        let acknowledge = UNNotificationAction(
            identifier: acknowledgeAction, title: L10n.string("notif.action.ack"), options: [])
        UNUserNotificationCenter.current().setNotificationCategories([
            UNNotificationCategory(identifier: category, actions: [acknowledge], intentIdentifiers: [])
        ])
    }

    static func content(
        for notification: PlannedNotification, placeName: String, timeZone: TimeZone
    ) -> UNNotificationContent {
        let content = UNMutableNotificationContent()
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        guard let event = notification.event else {
            content.title = "Horizon"
            content.body = L10n.string("notif.refill")
            return content
        }

        content.title = L10n.string("alarm.title.\(event.kind.rawValue)")
        content.categoryIdentifier = category
        content.threadIdentifier = event.id
        var userInfo: [String: String] = [eventIDKey: event.id, kindKey: event.kind.rawValue]

        switch notification.kind {
        case .followUp:
            content.body = L10n.string("notif.followUp.\(event.kind.rawValue)")
            userInfo[bodyKey] = content.body
        default:
            let body = L10n.format(
                "notif.body.\(event.kind.rawValue)", Fmt.time(event.date, in: timeZone), placeName)
            userInfo[bodyKey] = body
            if let following = notification.following {
                let next = L10n.format(
                    "notif.next.\(following.kind.rawValue)", Fmt.time(following.date, in: timeZone))
                userInfo[nextKey] = next
                // The plain notification has no tinted band, so the line goes under the body.
                content.body = [body, next].joined(separator: "\n")
            } else {
                content.body = body
            }
        }
        content.userInfo = userInfo
        return content
    }
}
