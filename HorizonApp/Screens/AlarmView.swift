import HorizonCore
import SwiftUI

/// The ringing alarm, full screen, in dawn or dusk colours.
struct AlarmView: View {
    @Environment(AppModel.self) private var model
    let event: SolarEvent

    private var tint: Color { Theme.color(event.kind) }

    var body: some View {
        VStack(spacing: 4) {
            emblem
                .frame(maxHeight: .infinity)
            Text(L10n.string("alarm.title.\(event.kind.rawValue)"))
                .font(.system(size: 19, weight: .semibold, design: .rounded))
            HStack(spacing: 4) {
                Text(Fmt.time(event.date, in: model.timeZone))
                if !model.placeName.isEmpty {
                    Text(verbatim: "·")
                    Text(model.placeName)
                }
            }
            .font(.system(size: 12, design: .rounded))
            .foregroundStyle(.white.opacity(0.7))
            .lineLimit(1)
            .minimumScaleFactor(0.7)

            Button {
                model.stopAlarm()
            } label: {
                Text("alarm.stop")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: Layout.size(42, compact: 36))
                    .background(Capsule().fill(Theme.gradient(event.kind)))
            }
            .buttonStyle(.plain)
            // Double tap of thumb and index finger stops the alarm without touching the screen.
            .handGestureShortcut(.primaryAction)
            .accessibilityIdentifier("alarm.stop")
            .padding(.top, 4)
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 6)
        .ignoresSafeArea(edges: .bottom)
        .background {
            LinearGradient(colors: [.black, tint.opacity(0.45)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    /// The sun on the horizon, with an arrow up for sunrise and down for sunset.
    private var emblem: some View {
        GeometryReader { proxy in
            let horizon = proxy.size.height * 0.86
            let radius = min(proxy.size.height * 0.4, 40)
            ZStack {
                Circle()
                    .fill(RadialGradient(
                        colors: [tint.opacity(0.5), .clear], center: .center, startRadius: radius, endRadius: radius * 2.6))
                    .frame(width: radius * 5.2, height: radius * 5.2)
                    .position(x: proxy.size.width / 2, y: horizon)
                ForEach([2.1, 1.55], id: \.self) { scale in
                    Circle()
                        .stroke(tint.opacity(0.45), lineWidth: 1.5)
                        .frame(width: radius * 2 * scale, height: radius * 2 * scale)
                        .position(x: proxy.size.width / 2, y: horizon)
                }
                Circle()
                    .fill(LinearGradient(colors: [Theme.sun, tint], startPoint: .top, endPoint: .bottom))
                    .frame(width: radius * 2, height: radius * 2)
                    .position(x: proxy.size.width / 2, y: horizon)
                Image(systemName: event.kind == .sunrise ? "arrow.up" : "arrow.down")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.black.opacity(0.7))
                    .position(x: proxy.size.width / 2, y: horizon - radius * 0.48)
            }
            // Only what is above the horizon shows.
            .mask(alignment: .top) { Rectangle().frame(height: horizon) }
            Rectangle()
                .fill(tint)
                .frame(height: 1.5)
                .position(x: proxy.size.width / 2, y: horizon)
        }
        .accessibilityHidden(true)
    }
}
