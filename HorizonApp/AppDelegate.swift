import UserNotifications
import WatchKit

final class AppDelegate: NSObject, WKApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching() {
        UNUserNotificationCenter.current().delegate = self
        Notifications.registerCategory()
        AppModel.shared.finishedLaunching()
    }

    func applicationDidBecomeActive() {
        AppModel.shared.becameActive()
    }

    /// Called when watchOS starts the app in the background for a scheduled alarm session.
    func handle(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        AppModel.shared.adopt(extendedRuntimeSession)
    }

    /// The alarm still shows when Horizon is on screen.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    /// "Got it", or a tap on the notification: the user has seen it, so the follow-up is dropped.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse
    ) async {
        guard response.actionIdentifier != UNNotificationDismissActionIdentifier,
            let eventID = response.notification.request.content.userInfo[Notifications.eventIDKey] as? String
        else { return }
        AppModel.shared.acknowledge(eventID: eventID)
    }
}
