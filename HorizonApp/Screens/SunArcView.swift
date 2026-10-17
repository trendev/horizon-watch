import HorizonCore
import SwiftUI

/// What the arc shows.
enum ArcStyle: Equatable {
    /// Daylight: the travelled part in colour, the rest dotted, the sun at this share of the day.
    case day(sunAt: Double)
    /// Night: the coming day's path dotted, the moon at this point of it (nil: no moon).
    case night(moonAt: Double?)
    /// Another day shown from the 7-day page: the whole path, no sun and no moon.
    case preview
}

/// Where things sit on the arc. The arc is a timeline, so it is mirrored in right-to-left
/// languages: sunrise on the right, time flowing right to left.
struct ArcGeometry {
    static let bellRadius: CGFloat = Layout.size(15, compact: 12)

    /// Height of the band above the arc that holds the countdown. A real winter arc is too low
    /// to hold it inside, so the countdown sits on top and the arc never crosses it.
    static let centreBand: CGFloat = Layout.size(48, compact: 38)

    let size: CGSize
    let mirrored: Bool
    /// The day's path. Without one (polar day or night, illustrations) a plain arch is drawn.
    let path: SunPath?
    var hasCentre = true

    var horizonY: CGFloat { size.height - Self.bellRadius - 2 }
    private var left: CGFloat { Self.bellRadius + 4 }
    private var span: CGFloat { size.width - 2 * left }
    private var top: CGFloat { hasCentre ? Self.centreBand : 0 }
    /// Room above the horizon for the full altitude scale, leaving space for the sun's disc.
    private var maxHeight: CGFloat { max(8, horizonY - top - 10) }

    /// The path at a share of the daylight: 0 is sunrise, 1 is sunset.
    func point(_ fraction: Double) -> CGPoint {
        position(path?.point(atFraction: fraction) ?? Self.arch(fraction))
    }

    func position(_ point: SunPathPoint) -> CGPoint {
        let x = left + span * point.x
        return CGPoint(x: mirrored ? size.width - x : x, y: horizonY - maxHeight * point.height)
    }

    func path(from start: Double, to end: Double) -> Path {
        var drawn = Path()
        guard end > start else { return drawn }
        let steps = max(2, Int((end - start) * 48))
        drawn.move(to: point(start))
        for step in 1...steps {
            drawn.addLine(to: point(start + (end - start) * Double(step) / Double(steps)))
        }
        return drawn
    }

    /// Where the countdown goes: the band above the arc.
    var centre: CGPoint {
        CGPoint(x: size.width / 2, y: Self.centreBand / 2)
    }

    private static func arch(_ fraction: Double) -> SunPathPoint {
        let x = min(max(fraction, 0), 1)
        return SunPathPoint(x: x, height: 0.85 * sin(.pi * x))
    }
}

/// The sun's arc above the horizon, with the two bells at its ends.
struct SunArcView<Centre: View>: View {
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    /// The day's real path, see `SunPath`.
    let path: SunPath?
    let style: ArcStyle
    /// 0 to 1 in the last hour before sunset: the sky warms up.
    var warmth: Double = 0
    /// The glow under the horizon. Off for the small onboarding illustration.
    var showsGround = true
    /// Reserve the countdown band above the arc. Off for the onboarding illustration.
    var showsCentre = true
    let settings: AlarmSettings
    let armed: SolarEvent.Kind?
    let toggle: (SolarEvent.Kind) -> Void
    /// Content inside the arc. Receives the width free of the arc at the label's height.
    @ViewBuilder let centre: (CGFloat) -> Centre

    var body: some View {
        GeometryReader { proxy in
            let geometry = ArcGeometry(
                size: proxy.size, mirrored: layoutDirection == .rightToLeft, path: path, hasCentre: showsCentre)
            ZStack {
                ground(geometry)
                switch style {
                case .preview:
                    geometry.path(from: 0, to: 1)
                        .stroke(arcGradient(geometry).opacity(0.75), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                case .day(let fraction):
                    day(geometry, fraction: fraction)
                case .night(let moon):
                    night(geometry, moon: moon)
                }
                if showsCentre {
                    centre(proxy.size.width * 0.8)
                        .frame(width: proxy.size.width * 0.92, height: ArcGeometry.centreBand)
                        .position(geometry.centre)
                }
                bell(.sunrise).position(geometry.point(0))
                bell(.sunset).position(geometry.point(1))
            }
        }
        // Positions are computed for the layout direction already.
        .environment(\.layoutDirection, .leftToRight)
    }

    private var isNight: Bool {
        if case .night = style { return true }
        return false
    }

    private func ground(_ geometry: ArcGeometry) -> some View {
        ZStack(alignment: .top) {
            if showsGround {
                LinearGradient(
                    colors: [(isNight ? Theme.night : Theme.dawn2).opacity(0.22 + 0.25 * warmth), .clear],
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

        geometry.path(from: fraction, to: 1)
            .stroke(Theme.secondary.opacity(0.8), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [0.5, 6]))
        geometry.path(from: 0, to: fraction)
            .stroke(arcGradient(geometry), style: StrokeStyle(lineWidth: 3, lineCap: .round))
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

    /// Dawn orange at the sunrise end, dusk pink at the sunset end.
    private func arcGradient(_ geometry: ArcGeometry) -> LinearGradient {
        let colors = [Theme.dawn, Theme.dawn2, Theme.dusk]
        return LinearGradient(
            colors: geometry.mirrored ? colors.reversed() : colors, startPoint: .leading, endPoint: .trailing)
    }

    @ViewBuilder
    private func night(_ geometry: ArcGeometry, moon fraction: Double?) -> some View {
        geometry.path(from: 0, to: 1)
            .stroke(Theme.night.opacity(0.8), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [0.5, 6]))
        if let fraction {
            moon(at: geometry.point(fraction))
        }
    }

    @ViewBuilder
    private func moon(at moon: CGPoint) -> some View {
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
