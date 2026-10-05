import Foundation
import UserNotifications

/// One local notification to schedule.
public struct PlannedNotification: Equatable, Sendable {
    public enum Kind: Sendable {
        case main
        case followUp
        /// Last request of the window: "Open Horizon to keep your alarms coming."
        case refill
    }

    public let id: String
    public let kind: Kind
    public let fireDate: Date
    public let event: SolarEvent?
    /// The event after this one, for the "Sunrise tomorrow 07:48" line.
    public let following: SolarEvent?
}

public enum NotificationPlan {
    /// watchOS keeps 64 pending local notifications per app.
    public static let systemLimit = 64
    /// The main notification of an armed occurrence waits this long, as a fallback for the session.
    public static let fallbackDelay: TimeInterval = 60
    public static let refillID = "refill"

    public static func mainID(_ eventID: String) -> String { "\(eventID).main" }
    public static func followUpID(_ eventID: String) -> String { "\(eventID).followup" }

    public static func make(
        plan: AlarmPlan, settings: AlarmSettings, armedOccurrenceID: String?
    ) -> [PlannedNotification] {
        guard !plan.occurrences.isEmpty else { return [] }

        var planned: [PlannedNotification] = []
        for event in plan.occurrences {
            let following = plan.event(after: event)
            let delay = event.id == armedOccurrenceID ? fallbackDelay : 0
            let fireDate = event.date.addingTimeInterval(delay)
            planned.append(PlannedNotification(
                id: mainID(event.id), kind: .main, fireDate: fireDate, event: event, following: following))
            if let interval = settings.followUp.interval {
                planned.append(PlannedNotification(
                    id: followUpID(event.id), kind: .followUp, fireDate: fireDate.addingTimeInterval(interval),
                    event: event, following: following))
            }
        }

        let lastFire = planned.map(\.fireDate).max() ?? plan.windowEnd
        planned.append(PlannedNotification(
            id: refillID, kind: .refill, fireDate: max(plan.windowEnd, lastFire.addingTimeInterval(60)),
            event: nil, following: nil))

        assert(planned.count <= systemLimit)
        return planned
    }
}

/// The part of `UNUserNotificationCenter` the scheduler uses, so tests can substitute it.
@MainActor
public protocol NotificationCenterProtocol {
    func removeAllPendingNotificationRequests()
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    func add(_ request: UNNotificationRequest) async throws
}

extension UNUserNotificationCenter: @MainActor NotificationCenterProtocol {}

@MainActor
public struct NotificationScheduler {
    private let center: any NotificationCenterProtocol

    public init(center: any NotificationCenterProtocol) {
        self.center = center
    }

    /// Replaces every pending request with the given plan. The app supplies the localized content.
    public func apply(
        _ planned: [PlannedNotification], content: (PlannedNotification) -> UNNotificationContent
    ) async throws {
        center.removeAllPendingNotificationRequests()
        for notification in planned {
            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second], from: notification.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            try await center.add(UNNotificationRequest(
                identifier: notification.id, content: content(notification), trigger: trigger))
        }
    }

    /// "Got it": the user saw the alarm, so its follow-up is dropped.
    public func acknowledge(eventID: String) {
        center.removePendingNotificationRequests(withIdentifiers: [NotificationPlan.followUpID(eventID)])
    }

    /// The persistent alarm started for this occurrence: neither the fallback nor its follow-up is needed.
    public func cancelAll(eventID: String) {
        center.removePendingNotificationRequests(withIdentifiers: [
            NotificationPlan.mainID(eventID), NotificationPlan.followUpID(eventID)
        ])
    }
}
