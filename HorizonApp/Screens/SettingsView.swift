import HorizonCore
import SwiftUI

/// Third page. The two toggles mirror the bells on the arc.
struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        List {
            alarmToggle(.sunrise)
            alarmToggle(.sunset)

            Picker(selection: binding(\.followUp)) {
                ForEach(FollowUp.allCases, id: \.self) { value in
                    Text(followUpLabel(value)).tag(value)
                }
            } label: {
                Label("settings.followUp", systemImage: "arrow.triangle.2.circlepath")
            }
            .pickerStyle(.navigationLink)
            .accessibilityIdentifier("settings.followUp")

            NavigationLink {
                LocationView()
            } label: {
                LabeledContent {
                    Text(model.location?.cityName ?? "")
                } label: {
                    Label("settings.location", systemImage: "location.fill")
                }
            }
            .accessibilityIdentifier("settings.location")

            Picker(selection: binding(\.vibration)) {
                Text("settings.vibration.signature").tag(Vibration.signature)
                Text("settings.vibration.standard").tag(Vibration.standard)
            } label: {
                Label("settings.vibration", systemImage: "waveform")
            }
            .pickerStyle(.navigationLink)
            .accessibilityIdentifier("settings.vibration")
        }
        .pageTitle(Text("settings.title"))
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<AlarmSettings, Value>) -> Binding<Value> {
        Binding(
            get: { model.settings[keyPath: keyPath] },
            set: { value in model.update { $0[keyPath: keyPath] = value } })
    }

    private func followUpLabel(_ value: FollowUp) -> String {
        value.minutes.map { L10n.format("settings.followUp.minutes", $0) } ?? L10n.string("settings.followUp.off")
    }

    private func alarmToggle(_ kind: SolarEvent.Kind) -> some View {
        Toggle(isOn: Binding(
            get: { model.settings.isEnabled(kind) },
            set: { enabled in model.update { $0.setEnabled(enabled, for: kind) } }
        )) {
            HStack(spacing: 8) {
                Image(systemName: kind == .sunrise ? "sunrise.fill" : "sunset.fill")
                    .foregroundStyle(Theme.color(kind))
                VStack(alignment: .leading, spacing: 0) {
                    AdaptiveLabel(L10n.eventName(kind))
                    if let date = model.plan?.displayDay.date(of: kind) {
                        Text(L10n.format("settings.everyDay", Fmt.time(date, in: model.timeZone)))
                            .font(.caption2)
                            .foregroundStyle(Theme.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
            }
        }
        .tint(Theme.color(kind))
        .accessibilityIdentifier("settings.\(kind.rawValue)")
    }
}
