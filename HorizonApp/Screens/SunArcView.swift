import HorizonCore
import SwiftUI

/// Where things sit on the arc. The arc is a timeline, so it is mirrored in right-to-left
/// languages: sunrise on the right, time flowing right to left.
struct ArcGeometry {
    static let bellRadius: CGFloat = Layout.size(15, compact: 12)

    let size: CGSize
    let mirrored: Bool

    var horizonY: CGFloat { size.height - Self.bellRadius - 2 }
    var radiusX: CGFloat { size.width / 2 - Self.bellRadius - 4 }
    var radiusY: CGFloat { max(8, min(horizonY - 10, radiusX * 1.05)) }

    /// 0 is sunrise, 1 is sunset.
    func point(_ fraction: Double) -> CGPoint {
        let angle = Double.pi * fraction
        let x = size.width / 2 - radiusX * cos(angle)
        return CGPoint(x: mirrored ? size.width - x : x, y: horizonY - radiusY * sin(angle))
    }

    func path(from start: Double, to end: Double) -> Path {
        var path = Path()
        guard end > start else { return path }
        let steps = max(2, Int((end - start) * 60))
        path.move(to: point(start))
        for step in 1...steps {
            path.addLine(to: point(start + (end - start) * Double(step) / Double(steps)))
        }
        return path
    }

    /// Centre of the space inside the arc, where the countdown goes.
    var centre: CGPoint {
        CGPoint(x: size.width / 2, y: horizonY - radiusY * 0.42)
    }
}

/// The sun's arc above the horizon, with the two bells at its ends.
struct SunArcView<Centre: View>: View {
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    /// Share of daylight elapsed, or nil at night.
    let fraction: Double?
    /// 0 to 1 in the last hour before sunset: the sky warms up.
    var warmth: Double = 0
    /// The glow under the horizon. Off for the small onboarding illustration.
    var showsGround = true
    let settings: AlarmSettings
    let armed: SolarEvent.Kind?
    let toggle: (SolarEvent.Kind) -> Void
    /// Content inside the arc. Receives the width free of the arc at the label's height.
    @ViewBuilder let centre: (CGFloat) -> Centre

    var body: some View {
        GeometryReader { proxy in
            let geometry = ArcGeometry(size: proxy.size, mirrored: layoutDirection == .rightToLeft)
            ZStack {
                ground(geometry)
                if let fraction {
                    day(geometry, fraction: fraction)
                } else {
                    night(geometry)
                }
                centre(geometry.radiusX * 1.2)
                    .frame(width: geometry.radiusX * 1.7)
                    .position(geometry.centre)
                bell(.sunrise).position(geometry.point(0))
                bell(.sunset).position(geometry.point(1))
            }
        }
        // Positions are computed for the layout direction already.
        .environment(\.layoutDirection, .leftToRight)
    }

    private func ground(_ geometry: ArcGeometry) -> some View {
        ZStack(alignment: .top) {
            if showsGround {
                LinearGradient(
                    colors: [(fraction == nil ? Theme.night : Theme.dawn2).opacity(0.22 + 0.25 * warmth), .clear],
                    startPoint: .top, endPoint: .bottom)
                    .frame(height: 46)
            }
            Rectangle()
                .fill(.white.opacity(0.28))
                .frame(height: 1)
        }
        .frame(width: geometry.size.width + 40, height: 46, alignment: .top)
        .position(x: geometry.size.width / 2, y: geometry.horizonY + 23)
    }

    @ViewBuilder
    private func day(_ geometry: ArcGeometry, fraction: Double) -> some View {
        let sun = geometry.point(fraction)
        let colors = [Theme.dawn, Theme.dawn2, Theme.dusk]

        geometry.path(from: fraction, to: 1)
            .stroke(Theme.secondary.opacity(0.8), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [0.5, 6]))
        geometry.path(from: 0, to: fraction)
            .stroke(
                LinearGradient(
                    colors: geometry.mirrored ? colors.reversed() : colors,
                    startPoint: .leading, endPoint: .trailing),
                style: StrokeStyle(lineWidth: 3, lineCap: .round))
        Circle()
            .fill(RadialGradient(colors: [Theme.dawn.opacity(0.55), .clear], center: .center, startRadius: 2, endRadius: 22))
            .frame(width: 44, height: 44)
            .position(sun)
            .opacity(isLuminanceReduced ? 0.3 : 1)
        Circle()
            .fill(Theme.sun)
            .frame(width: 14, height: 14)
            .position(sun)
    }

    @ViewBuilder
    private func night(_ geometry: ArcGeometry) -> some View {
        let moon = geometry.point(0.5)
        geometry.path(from: 0, to: 1)
            .stroke(Theme.night.opacity(0.8), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [0.5, 6]))
        Circle()
            .fill(RadialGradient(colors: [Theme.night.opacity(0.6), .clear], center: .center, startRadius: 2, endRadius: 20))
            .frame(width: 40, height: 40)
            .position(moon)
        Image(systemName: "moon.fill")
            .font(.system(size: 13))
            .foregroundStyle(.white)
            .position(moon)
    }

    private func bell(_ kind: SolarEvent.Kind) -> some View {
        let enabled = settings.isEnabled(kind)
        return Button {
            toggle(kind)
        } label: {
            ZStack {
                if armed == kind {
                    Circle()
                        .stroke(Theme.color(kind), lineWidth: 1.5)
                        .frame(width: ArcGeometry.bellRadius * 2 + 8, height: ArcGeometry.bellRadius * 2 + 8)
                }
                Circle()
                    .fill(enabled ? AnyShapeStyle(Theme.gradient(kind)) : AnyShapeStyle(Theme.card))
                    .overlay(Circle().stroke(.white.opacity(enabled ? 0 : 0.15), lineWidth: 1))
                    .shadow(color: enabled ? Theme.color(kind).opacity(0.6) : .clear, radius: 5)
                    .frame(width: ArcGeometry.bellRadius * 2, height: ArcGeometry.bellRadius * 2)
                Image(systemName: enabled ? "bell.fill" : "bell.slash.fill")
                    .font(.system(size: Layout.size(12, compact: 10), weight: .semibold))
                    .foregroundStyle(enabled ? .black : Theme.secondary)
            }
            .frame(width: Layout.size(44, compact: 38), height: Layout.size(44, compact: 38))
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("bell.\(kind.rawValue)")
        .accessibilityLabel(L10n.string(L10n.eventName(kind)))
        .accessibilityValue(L10n.string(enabled ? "control.on" : "control.off"))
        .accessibilityAddTraits(armed == kind ? .isSelected : [])
    }
}
