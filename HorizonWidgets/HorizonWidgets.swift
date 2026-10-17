import AppIntents
import HorizonCore
import SwiftUI
import WidgetKit

/// Every complication opens the app, which arms the next persistent alarm.
let openURL = URL(string: "horizon://open")!

@main
struct HorizonWidgetBundle: WidgetBundle {
    var body: some Widget {
        SolarGaugeWidget()
        NextEventWidget()
        CountdownWidget()
        SunAlarmsControl()
    }
}

private extension View {
    func complication() -> some View {
        self
            .widgetURL(openURL)
            .containerBackground(for: .widget) {
                LinearGradient(colors: [Theme.dusk2.opacity(0.25), Theme.card], startPoint: .top, endPoint: .bottom)
            }
    }
}

struct SolarGaugeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SolarGauge", provider: SolarTimelineProvider()) { entry in
            GaugeCornerView(entry: entry).complication()
        }
        .configurationDisplayName("widget.gauge.name")
        .description("widget.description")
        .supportedFamilies([.accessoryCorner])
    }
}

struct NextEventWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NextEvent", provider: SolarTimelineProvider()) { entry in
            NextEventView(entry: entry).complication()
        }
        .configurationDisplayName("widget.next.name")
        .description("widget.description")
        .supportedFamilies([.accessoryCorner, .accessoryRectangular, .accessoryInline])
    }
}

struct CountdownWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Countdown", provider: SolarTimelineProvider()) { entry in
            CountdownView(entry: entry).complication()
        }
        .configurationDisplayName("widget.countdown.name")
        .description("widget.description")
        .supportedFamilies([.accessoryCorner, .accessoryCircular])
    }
}

private struct NextEventView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SolarEntry

    var body: some View {
        switch family {
        case .accessoryCorner: NextEventCornerView(entry: entry)
        case .accessoryInline: NextEventInlineView(entry: entry)
        default: NextEventRectangularView(entry: entry)
        }
    }
}

private struct CountdownView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SolarEntry

    var body: some View {
        switch family {
        case .accessoryCorner: CountdownCornerView(entry: entry)
        default: CountdownCircularView(entry: entry)
        }
    }
}

// MARK: - Control Center

/// "Sun alarms": both alarms on or off at once. It reflects the bells' state.
struct SunAlarmsControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "fr.trendev.horizon.sunAlarms", provider: Provider()) { isOn in
            ControlWidgetToggle("control.name", isOn: isOn, action: SetSunAlarmsIntent()) { isOn in
                Label(isOn ? "control.on" : "control.off", systemImage: isOn ? "bell.fill" : "bell.slash.fill")
            }
            .tint(Theme.dusk)
        }
        .displayName("control.name")
    }

    struct Provider: ControlValueProvider {
        var previewValue: Bool { true }

        func currentValue() async throws -> Bool {
            SettingsStore.shared.alarm.anyEnabled
        }
    }
}

// MARK: - Previews

private var sample: SolarEntry {
    SolarEntry(date: .now, snapshot: .sample, relevance: nil, isSample: true)
}

#Preview("Gauge", as: .accessoryCorner) { SolarGaugeWidget() } timeline: { sample }
#Preview("Next, corner", as: .accessoryCorner) { NextEventWidget() } timeline: { sample }
#Preview("Next, rectangular", as: .accessoryRectangular) { NextEventWidget() } timeline: { sample }
#Preview("Next, inline", as: .accessoryInline) { NextEventWidget() } timeline: { sample }
#Preview("Countdown, corner", as: .accessoryCorner) { CountdownWidget() } timeline: { sample }
#Preview("Countdown, circular", as: .accessoryCircular) { CountdownWidget() } timeline: { sample }
