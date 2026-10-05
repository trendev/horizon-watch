import HorizonCore
import SwiftUI
import UserNotifications
import WatchKit

/// Long look of an alarm notification: the body, then a tinted band with the next event.
struct SolarNotificationView: View {
    var title = ""
    var message = ""
    var next: String?
    var kind: SolarEvent.Kind = .sunset

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(message)
                .font(.footnote)
            if let next {
                HStack(spacing: 6) {
                    Image(systemName: kind == .sunset ? "sunrise.fill" : "sunset.fill")
                        .foregroundStyle(Theme.dawn)
                    Text(next)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(
                            colors: [Theme.dusk2.opacity(0.35), Theme.dusk.opacity(0.3)],
                            startPoint: .leading, endPoint: .trailing)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

final class SolarNotificationController: WKUserNotificationHostingController<SolarNotificationView> {
    private var view = SolarNotificationView()

    override var body: SolarNotificationView { view }

    override func didReceive(_ notification: UNNotification) {
        let content = notification.request.content
        let info = content.userInfo
        view = SolarNotificationView(
            title: content.title,
            message: info[Notifications.bodyKey] as? String ?? content.body,
            next: info[Notifications.nextKey] as? String,
            kind: (info[Notifications.kindKey] as? String).flatMap(SolarEvent.Kind.init(rawValue:)) ?? .sunset)
    }
}
