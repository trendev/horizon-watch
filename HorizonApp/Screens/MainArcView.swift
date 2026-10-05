import HorizonCore
import SwiftUI

/// The main screen: the sun's arc, the countdown, the two bells.
struct MainArcView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    /// The countdown was tapped: it targets the other event until the screen next wakes.
    @State private var showsOtherEvent = false

    var body: some View {
        Group {
            if let plan = model.plan {
                content(plan)
            } else {
                missingLocation
            }
        }
        .pageTitle(Text(verbatim: "Horizon"))
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { showsOtherEvent = false }
        }
        .onChange(of: isLuminanceReduced) { _, _ in
            showsOtherEvent = false
        }
    }

    private func target(_ plan: AlarmPlan) -> SolarEvent? {
        guard let next = plan.nextEvent else { return nil }
        guard showsOtherEvent else { return next }
        return plan.nextEvent(of: next.kind == .sunset ? .sunrise : .sunset) ?? next
    }

    private func content(_ plan: AlarmPlan) -> some View {
        let target = target(plan)
        return VStack(spacing: 2) {
            TimelineView(.periodic(from: .now, by: 60)) { _ in
                let now = model.now()
                SunArcView(
                    fraction: plan.isNight ? nil : plan.daylightFraction(at: now),
                    warmth: warmth(plan, now: now),
                    settings: model.settings,
                    armed: SolarEvent.Kind.allCases.first(where: model.isArmed),
                    toggle: model.toggle
                ) { width in
                    centre(plan, target: target, labelWidth: width)
                }
            }
            .frame(minHeight: 64, maxHeight: .infinity)
            .overlay(alignment: .bottom) { daylight(plan) }

            VStack(spacing: -2) {
                eventLabels(plan, target: target)
                HStack(spacing: 4) {
                    eventTime(.sunrise, plan: plan, target: target)
                    Spacer(minLength: 0)
                    eventTime(.sunset, plan: plan, target: target)
                }
            }
            .padding(.horizontal, 6)

            footer(plan)
                .padding(.top, 3)
        }
        .padding(.horizontal, 4)
        .padding(.bottom, Layout.size(8, compact: 5))
        .ignoresSafeArea(edges: .bottom)
        .opacity(isLuminanceReduced ? 0.6 : 1)
    }

    // MARK: - Arc centre

    @ViewBuilder
    private func centre(_ plan: AlarmPlan, target: SolarEvent?, labelWidth: CGFloat) -> some View {
        if plan.displayDay.polar != .none {
            Text(plan.displayDay.polar == .day ? "polar.noSunset" : "polar.noSunrise")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
                .accessibilityIdentifier("countdown")
        } else if let target {
            Button {
                showsOtherEvent.toggle()
            } label: {
                CountdownView(kind: target.kind, target: model.wallClock(target.date), labelWidth: labelWidth)
            }
            .buttonStyle(.plain)
        }
    }

    /// The sky warms up during the last hour before sunset.
    private func warmth(_ plan: AlarmPlan, now: Date) -> Double {
        guard let next = plan.nextEvent, next.kind == .sunset else { return 0 }
        let remaining = next.date.timeIntervalSince(now)
        return remaining < 3600 ? 1 - max(0, remaining) / 3600 : 0
    }

    @ViewBuilder
    private func daylight(_ plan: AlarmPlan) -> some View {
        if let length = plan.displayDay.dayLength {
            Text(L10n.format(
                plan.displayIsTomorrow ? "main.daylight.tomorrow" : "main.daylight", Fmt.duration(length)))
                .font(.system(size: Layout.size(10, compact: 8.5), weight: .medium, design: .rounded))
                .foregroundStyle(Theme.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, ArcGeometry.bellRadius * 2 + 10)
                .accessibilityIdentifier("daylight")
        }
    }

    // MARK: - Times under the horizon

    /// After a tap on the countdown the labels follow: "Sunrise tomorrow 07:48".
    private func followsTarget(_ kind: SolarEvent.Kind, plan: AlarmPlan, target: SolarEvent?) -> Bool {
        showsOtherEvent && target?.kind == kind && target?.day != plan.displayDay.day
    }

    private func eventLabels(_ plan: AlarmPlan, target: SolarEvent?) -> some View {
        let sunrise = followsTarget(.sunrise, plan: plan, target: target) ? "event.sunrise.tomorrow" : "event.sunrise"
        return AdaptiveLabelPair(leading: sunrise, trailing: "event.sunset") { text in
            text.foregroundStyle(model.settings.sunriseEnabled ? Theme.dawn : Theme.secondary)
        } trailingStyle: { text in
            text.foregroundStyle(model.settings.sunsetEnabled ? Theme.dusk : Theme.secondary)
        }
        .font(.system(size: Layout.size(12, compact: 11), weight: .semibold, design: .rounded))
    }

    private func eventTime(_ kind: SolarEvent.Kind, plan: AlarmPlan, target: SolarEvent?) -> some View {
        let date = followsTarget(kind, plan: plan, target: target) ? target?.date : plan.displayDay.date(of: kind)
        return Text(date.map { Fmt.time($0, in: model.timeZone) } ?? "–")
            .font(.system(size: Layout.size(23, compact: 18), weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(model.settings.isEnabled(kind) ? .white : Theme.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.55)
            .accessibilityIdentifier("time.\(kind.rawValue)")
    }

    // MARK: - Pill and toast

    @ViewBuilder
    private func footer(_ plan: AlarmPlan) -> some View {
        if let toast = model.toast {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(toast.kind.map(Theme.color) ?? Theme.dawn)
                VStack(alignment: .leading, spacing: 0) {
                    Text(toast.title)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                    if let subtitle = toast.subtitle {
                        Text(subtitle)
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(Theme.secondary)
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
            }
            .pill(tint: toast.kind.map(Theme.color) ?? Theme.dawn)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("toast")
        } else if plan.nextOccurrence == nil && model.settings.anyEnabled {
            // Alarms are on but the sun gives nothing to ring for (polar day or night).
            Color.clear.frame(height: Layout.size(30, compact: 25))
        } else {
            let next = plan.nextOccurrence
            HStack(spacing: 6) {
                Image(systemName: "bell.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(next.map { Theme.color($0.kind) } ?? Theme.secondary)
                Text(next == nil ? "mode.none" : model.isNextOccurrenceArmed ? "mode.persistent" : "mode.automatic")
                    .font(.system(size: Layout.size(13, compact: 12), weight: .semibold, design: .rounded))
                    .foregroundStyle(next == nil ? Theme.secondary : .white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .pill(tint: nil)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("pill")
        }
    }

    private var missingLocation: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text("location.denied")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                NavigationLink("location.chooseCity") {
                    CityPickerView()
                }
            }
        }
    }
}

private extension View {
    func pill(tint: Color?) -> some View {
        self
            .padding(.horizontal, 10)
            .frame(height: Layout.size(30, compact: 25))
            .background(
                Capsule().fill(tint.map { AnyShapeStyle($0.opacity(0.18)) } ?? AnyShapeStyle(Theme.card)))
            .overlay(Capsule().stroke((tint ?? .clear).opacity(0.5), lineWidth: 1))
    }
}
