import AppIntents
import HorizonCore
import WidgetKit

/// Action of the Control Center toggle: both alarms on or off at once (holidays, a night outside).
///
/// The toggle's intent can run in the widget extension, which has no access to the app's
/// pending notifications. So it brings Horizon forward, and the app replans: that is what
/// really cancels, or restores, the alarms.
struct SetSunAlarmsIntent: SetValueIntent {
    static let title: LocalizedStringResource = "control.name"
    static let openAppWhenRun = true

    @Parameter(title: "control.name")
    var value: Bool

    func perform() async throws -> some IntentResult {
        let store = SettingsStore.shared
        var settings = store.alarm
        settings.sunriseEnabled = value
        settings.sunsetEnabled = value
        store.alarm = settings
        WidgetCenter.shared.reloadAllTimelines()
        ControlCenter.shared.reloadAllControls()
        return .result()
    }
}
