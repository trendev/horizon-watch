import SwiftUI

@main
struct HorizonApp: App {
    @WKApplicationDelegateAdaptor private var delegate: AppDelegate
    @State private var model = AppModel.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
        }
        .backgroundTask(.appRefresh(AppModel.refreshTask)) {
            await AppModel.shared.backgroundRefresh()
        }

        WKNotificationScene(controller: SolarNotificationController.self, category: Notifications.category)
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if model.onboardingDone {
            NavigationStack {
                MainArcView()
            }
        } else {
            OnboardingView()
        }
    }
}
