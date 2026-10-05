import AppIntents

/// "Open Horizon", assignable to the Action button of an Apple Watch Ultra. Opening the app
/// arms the next occurrence as a persistent alarm.
struct OpenHorizonIntent: AppIntent {
    static let title: LocalizedStringResource = "intent.open"
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppModel.shared.confirmsArming = true
        return .result()
    }
}

struct HorizonShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenHorizonIntent(),
            phrases: ["Open \(.applicationName)"],
            shortTitle: "intent.open",
            systemImageName: "sunrise.fill")
    }
}
