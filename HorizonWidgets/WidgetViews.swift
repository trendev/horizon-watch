import HorizonCore
import SwiftUI
import WidgetKit

extension SolarEntry {
    /// Live countdown range. In the editor preview it is anchored on now so the sample ticks.
    var timerRange: ClosedRange<Date>? {
        guard let snapshot else { return nil }
        if isSample {
            let remaining: TimeInterval = 3 * 3600 + 16 * 60 + 39
            return Date.now...Date.now.addingTimeInterval(remaining)
        }
        return min(date, snapshot.next.date)...snapshot.next.date
    }

    var progress: Double {
        guard let snapshot else { return 0 }
        return isSample ? 0.72 : snapshot.moment.progress(at: date)
    }
}

extension SolarSnapshot {
    var tint: Color { isNight ? Theme.night : Theme.dusk }
    var gradient: Gradient {
        isNight ? Gradient(colors: [Theme.dusk2, Theme.night]) : Gradient(colors: [Theme.dawn, Theme.dawn2, Theme.dusk])
    }
    var symbol: String { isNight ? "sunrise.fill" : "sunset.fill" }
    var time: String { Fmt.time(next.date, in: timeZone) }
    var name: String { L10n.string(L10n.eventName(next.kind)) }
    var shortName: String { L10n.string(L10n.eventName(next.kind) + ".short") }
    var countdownLabel: String { L10n.string("main.countdown.\(next.kind.rawValue).short") }
}

/// Shown until the app has a location.
struct EmptyComplication: View {
    var body: some View {
        Image(systemName: "sun.horizon.fill")
            .widgetAccentable()
    }
}

// MARK: - Corner

/// Curved gauge from sunrise to sunset with the sun in the corner; violet with a moon at night.
struct GaugeCornerView: View {
    let entry: SolarEntry

    var body: some View {
        if let snapshot = entry.snapshot {
            Image(systemName: snapshot.isNight ? "moon.fill" : "sun.max.fill")
                .font(.system(size: 20))
                .foregroundStyle(snapshot.isNight ? Theme.night : Theme.dawn)
                .widgetAccentable()
                .widgetLabel {
                    Gauge(value: entry.progress) { EmptyView() }
                        .tint(snapshot.gradient)
                }
        } else {
            EmptyComplication()
        }
    }
}

/// "SUNSET 19:33" in curved text.
struct NextEventCornerView: View {
    let entry: SolarEntry

    var body: some View {
        if let snapshot = entry.snapshot {
            Image(systemName: snapshot.symbol)
                .font(.system(size: 20))
                .foregroundStyle(snapshot.tint)
                .widgetAccentable()
                .widgetLabel {
                    Text([snapshot.shortName.localizedUppercase, snapshot.time].joined(separator: " "))
                        .foregroundStyle(snapshot.tint)
                }
        } else {
            EmptyComplication()
        }
    }
}

/// Time left in the corner, with the gauge along the bezel.
struct CountdownCornerView: View {
    let entry: SolarEntry

    var body: some View {
        if let snapshot = entry.snapshot, let range = entry.timerRange {
            Text(timerInterval: range, countsDown: true)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .widgetLabel {
                    Gauge(value: entry.progress) { EmptyView() }
                        .tint(snapshot.gradient)
                }
        } else {
            EmptyComplication()
        }
    }
}

// MARK: - Circular

/// Ring of daylight progress with the remaining time in the centre.
struct CountdownCircularView: View {
    let entry: SolarEntry

    var body: some View {
        if let snapshot = entry.snapshot, let range = entry.timerRange {
            Gauge(value: entry.progress) {
                Image(systemName: snapshot.symbol)
            } currentValueLabel: {
                Text(timerInterval: range, countsDown: true)
                    .monospacedDigit()
                    .minimumScaleFactor(0.4)
            }
            .gaugeStyle(.accessoryCircular)
            .tint(snapshot.gradient)
            .widgetAccentable()
        } else {
            EmptyComplication()
        }
    }
}

// MARK: - Inline

/// Sunset symbol, "19:33 · in 3 hr". The relative part comes from a formatter at the entry's
/// date, refreshed with the timeline every 15 minutes.
struct NextEventInlineView: View {
    let entry: SolarEntry

    var body: some View {
        if let snapshot = entry.snapshot {
            Label {
                Text([snapshot.time, Fmt.relative(entry.date, to: snapshot.next.date, future: true)]
                    .joined(separator: " · "))
            } icon: {
                Image(systemName: snapshot.symbol)
            }
        } else {
            Label {
                Text(verbatim: "Horizon")
            } icon: {
                Image(systemName: "sun.horizon.fill")
            }
        }
    }
}

// MARK: - Rectangular

/// On a watch face: "SUNSET IN", the live countdown, the day's sun bar, "Sunset 19:33 · Paris".
/// In the Smart Stack: a mini arc, "Sunset 19:33" and the countdown.
struct NextEventRectangularView: View {
    @Environment(\.showsWidgetContainerBackground) private var isInSmartStack
    let entry: SolarEntry

    var body: some View {
        if let snapshot = entry.snapshot, let range = entry.timerRange {
            if isInSmartStack {
                stack(snapshot, range: range)
            } else {
                face(snapshot, range: range)
            }
        } else {
            HStack {
                EmptyComplication()
                Text(verbatim: "Horizon").font(.headline)
                Spacer(minLength: 0)
            }
        }
    }

    private func face(_ snapshot: SolarSnapshot, range: ClosedRange<Date>) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(snapshot.countdownLabel.localizedUppercase)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(snapshot.tint)
                .widgetAccentable()
            Text(timerInterval: range, countsDown: true)
                .font(.system(size: 26, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.6)
            SunBar(progress: entry.progress, gradient: snapshot.gradient)
                .frame(height: 8)
            caption(snapshot)
        }
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func stack(_ snapshot: SolarSnapshot, range: ClosedRange<Date>) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack {
                Text(verbatim: "Horizon")
                    .foregroundStyle(Theme.dawn)
                    .widgetAccentable()
                Spacer(minLength: 0)
                Text(snapshot.isTomorrow ? "widget.tomorrow" : "widget.tonight")
                    .foregroundStyle(Theme.secondary)
            }
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            MiniArc(
                progress: snapshot.isNight ? nil : entry.progress, path: snapshot.path, gradient: snapshot.gradient)
                .frame(maxHeight: .infinity)
            HStack(alignment: .firstTextBaseline) {
                Text([snapshot.name, snapshot.time].joined(separator: " "))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .minimumScaleFactor(0.6)
                Spacer(minLength: 2)
                Text(timerInterval: range, countsDown: true)
                    .font(.system(size: 12, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.secondary)
                    .multilineTextAlignment(.trailing)
            }
        }
        .lineLimit(1)
    }

    private func caption(_ snapshot: SolarSnapshot) -> some View {
        HStack(spacing: 3) {
            Text(snapshot.name)
            Text(snapshot.time)
            if !snapshot.placeName.isEmpty {
                Text(verbatim: "·")
                Text(snapshot.placeName)
            }
        }
        .font(.system(size: 11, design: .rounded))
        .foregroundStyle(Theme.secondary)
        .minimumScaleFactor(0.7)
    }
}

/// A line from sunrise to sunset with a marker where the sun is.
struct SunBar: View {
    @Environment(\.layoutDirection) private var layoutDirection
    let progress: Double
    let gradient: Gradient

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width - 6
            let x = 3 + width * (layoutDirection == .rightToLeft ? 1 - progress : progress)
            let y = proxy.size.height / 2
            ZStack {
                Capsule().fill(Theme.secondary.opacity(0.4)).frame(height: 2)
                Capsule()
                    .fill(LinearGradient(gradient: gradient, startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(0, width * progress), height: 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 3)
                    .widgetAccentable()
                Circle().fill(Theme.sun).frame(width: 6, height: 6).position(x: x, y: y)
                    .widgetAccentable()
            }
        }
    }
}

/// The main screen's arc, reduced to a line and a dot: the same real path of the sun.
struct MiniArc: View {
    @Environment(\.layoutDirection) private var layoutDirection
    /// Daylight elapsed, or nil at night.
    let progress: Double?
    let path: SunPath?
    let gradient: Gradient

    var body: some View {
        GeometryReader { proxy in
            let mirrored = layoutDirection == .rightToLeft
            let horizon = proxy.size.height - 3
            let left: CGFloat = 6
            let span = proxy.size.width - 2 * left
            let maxHeight = max(4, horizon - 4)
            let point: (Double) -> CGPoint = { fraction in
                let sun = path?.point(atFraction: fraction)
                    ?? SunPathPoint(x: fraction, height: 0.85 * sin(.pi * fraction))
                let x = left + span * sun.x
                return CGPoint(x: mirrored ? proxy.size.width - x : x, y: horizon - maxHeight * sun.height)
            }
            let arc: (Double, Double) -> Path = { start, end in
                var path = Path()
                guard end > start else { return path }
                path.move(to: point(start))
                for step in 1...24 {
                    path.addLine(to: point(start + (end - start) * Double(step) / 24))
                }
                return path
            }
            ZStack {
                Rectangle().fill(Theme.secondary.opacity(0.5)).frame(height: 1)
                    .position(x: proxy.size.width / 2, y: horizon)
                arc(progress ?? 0, 1)
                    .stroke(Theme.secondary, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [0.5, 4]))
                if let progress {
                    arc(0, progress)
                        .stroke(
                            LinearGradient(gradient: gradient, startPoint: .leading, endPoint: .trailing),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .widgetAccentable()
                    Circle().fill(Theme.sun).frame(width: 7, height: 7).position(point(progress))
                        .widgetAccentable()
                }
                Circle().fill(Theme.dawn).frame(width: 6, height: 6).position(point(0))
                Circle().fill(Theme.dusk).frame(width: 6, height: 6).position(point(1))
            }
        }
        .environment(\.layoutDirection, .leftToRight)
    }
}
