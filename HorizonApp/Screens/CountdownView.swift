import HorizonCore
import SwiftUI

/// Time left until an event. The system drives the digits (`Text(timerInterval:)`), so no app
/// code runs every second.
struct CountdownView: View {
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    let kind: SolarEvent.Kind
    /// Wall-clock instant of the event.
    let target: Date
    var labelWidth: CGFloat?

    var body: some View {
        VStack(spacing: -2) {
            AdaptiveLabel("main.countdown.\(kind.rawValue)")
                .font(.system(size: Layout.size(12, compact: 10), weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.color(kind))
                .frame(maxWidth: labelWidth)
            if isLuminanceReduced {
                // Wrist down: hours and minutes only, once a minute.
                TimelineView(.everyMinute) { context in
                    Text(Fmt.duration(target.timeIntervalSince(context.date)))
                        .font(.system(size: Layout.size(28, compact: 21), weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }
            } else {
                // The layout changes once, an hour before the event.
                TimelineView(.explicit([target.addingTimeInterval(-3600), target])) { _ in
                    live
                }
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("countdown")
    }

    @ViewBuilder
    private var live: some View {
        let now = Date()
        let range = min(now, target)...target
        if target.timeIntervalSince(now) < 3600 {
            Text(timerInterval: range, countsDown: true, showsHours: false)
                .font(.system(size: Layout.size(36, compact: 27), weight: .semibold, design: .rounded))
                .monospacedDigit()
        } else {
            Text(timerInterval: range, countsDown: true, showsHours: true)
                .font(.system(size: Layout.size(30, compact: 22), weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(secondsDimmed(hourDigits: target.timeIntervalSince(now) >= 36_000 ? 2 : 1))
        }
    }

    /// Dims the seconds of "3:16:39". The timer text is a single run that cannot be styled in
    /// parts, but its digits have a fixed width, so the seconds always cover the same share of it.
    private func secondsDimmed(hourDigits: Int) -> LinearGradient {
        let colon = 0.45
        let total = Double(hourDigits + 4) + 2 * colon
        let split = (total - 2 - colon) / total
        return LinearGradient(
            stops: [
                .init(color: .white, location: 0), .init(color: .white, location: split),
                .init(color: Theme.secondary, location: split), .init(color: Theme.secondary, location: 1)
            ],
            startPoint: .leading, endPoint: .trailing)
    }
}
