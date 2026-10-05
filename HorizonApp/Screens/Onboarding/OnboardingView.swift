import HorizonCore
import SwiftUI

/// First launch: four screens, no account.
struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @State private var step = 0
    @State private var choosesCity = false
    @State private var isWorking = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    dots
                    switch step {
                    case 0: welcome
                    case 1: locationStep
                    case 2: notificationStep
                    default: alarmsStep
                    }
                }
                .padding(.horizontal, 6)
            }
            .navigationDestination(isPresented: $choosesCity) {
                CityPickerView {
                    choosesCity = false
                    step = 2
                }
            }
        }
    }

    private var dots: some View {
        HStack(spacing: 4) {
            ForEach(0..<4, id: \.self) { index in
                Capsule()
                    .fill(index == step ? .white : Theme.secondary.opacity(0.5))
                    .frame(width: index == step ? 12 : 5, height: 5)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Steps

    private var welcome: some View {
        VStack(spacing: 6) {
            SunArcView(
                fraction: 0.5, showsGround: false, settings: AlarmSettings(), armed: nil, toggle: { _ in }
            ) { _ in EmptyView() }
                .frame(width: 130, height: 62)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            Text(verbatim: "Horizon")
                .font(.system(size: 20, weight: .bold, design: .rounded))
            Text("onb.tagline")
                .font(.footnote)
                .multilineTextAlignment(.center)
            action("onb.start", kind: .sunrise) { step = 1 }
        }
    }

    private var locationStep: some View {
        page(icon: "location.fill", tint: Theme.dawn, title: "onb.location.title", message: "onb.location.body") {
            action("onb.allow", kind: .sunrise) {
                Task {
                    isWorking = true
                    defer { isWorking = false }
                    if model.overrides.coordinates != nil {
                        step = 2
                    } else if await model.locationProvider.requestAuthorization() {
                        await model.refreshLocation()
                        // No fix (indoors): the city list still gives sun times.
                        if model.location == nil { choosesCity = true } else { step = 2 }
                    } else {
                        choosesCity = true
                    }
                }
            }
        }
    }

    private var notificationStep: some View {
        page(icon: "bell.fill", tint: Theme.dusk, title: "onb.notif.title", message: "onb.notif.body") {
            action("onb.allow", kind: .sunset) {
                Task {
                    await model.requestNotificationAuthorization()
                    step = 3
                }
            }
        }
    }

    private var alarmsStep: some View {
        VStack(spacing: 6) {
            Text("onb.alarms.title")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
            alarmRow(.sunrise)
            alarmRow(.sunset)
            Text("onb.alarms.hint")
                .font(.caption2)
                .foregroundStyle(Theme.secondary)
                .multilineTextAlignment(.center)
            action("onb.done", kind: .sunrise) { model.finishOnboarding() }
        }
    }

    // MARK: - Pieces

    private func page(
        icon: String, tint: Color, title: LocalizedStringKey, message: LocalizedStringKey,
        @ViewBuilder button: () -> some View
    ) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(tint)
                .frame(width: 42, height: 42)
                .background(Circle().fill(tint.opacity(0.2)))
            Text(title)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
            Text(message)
                .font(.footnote)
                .multilineTextAlignment(.center)
            button()
        }
    }

    private func action(_ title: LocalizedStringKey, kind: SolarEvent.Kind, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(Capsule().fill(Theme.gradient(kind)))
        }
        .buttonStyle(.plain)
        .disabled(isWorking)
        .accessibilityIdentifier("onboarding.action")
    }

    private func alarmRow(_ kind: SolarEvent.Kind) -> some View {
        Toggle(isOn: Binding(
            get: { model.settings.isEnabled(kind) },
            set: { enabled in model.update { $0.setEnabled(enabled, for: kind) } }
        )) {
            HStack(spacing: 6) {
                Image(systemName: kind == .sunrise ? "sunrise.fill" : "sunset.fill")
                    .foregroundStyle(Theme.color(kind))
                VStack(alignment: .leading, spacing: 0) {
                    AdaptiveLabel(L10n.eventName(kind))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                    Text(subtitle(kind))
                        .font(.caption2)
                        .foregroundStyle(Theme.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
        .tint(Theme.color(kind))
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
        .accessibilityIdentifier("onboarding.\(kind.rawValue)")
    }

    /// "07:48 tomorrow", "19:33 tonight"
    private func subtitle(_ kind: SolarEvent.Kind) -> String {
        guard let plan = model.plan, let event = plan.nextEvent(of: kind) else { return "" }
        let time = Fmt.time(event.date, in: model.timeZone)
        if event.day > plan.today.day {
            return L10n.format("onb.alarms.tomorrow", time)
        }
        return kind == .sunset ? L10n.format("onb.alarms.today", time) : time
    }
}
