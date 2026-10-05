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
    @State private var page = 0

    var body: some View {
        if model.onboardingDone {
            NavigationStack {
                // Three stacked pages, moved through with the Digital Crown.
                TabView(selection: $page) {
                    MainArcView().tag(0)
                    WeekView(page: $page).tag(1)
                    SettingsView().tag(2)
                }
                .tabViewStyle(.verticalPage)
            }
            .fullScreenCover(item: Binding(get: { model.ringing }, set: { _ in })) { event in
                AlarmView(event: event)
            }
        } else {
            OnboardingView()
        }
    }
}
