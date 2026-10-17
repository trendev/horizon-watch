import HorizonCore
import SwiftUI

/// The mockup's palette.
enum Theme {
    static let dawn = Color(red: 1.0, green: 0.71, blue: 0.28)       // #FFB547
    static let dawn2 = Color(red: 1.0, green: 0.54, blue: 0.24)      // #FF8A3D
    static let dusk = Color(red: 1.0, green: 0.37, blue: 0.38)       // #FF5E62
    static let dusk2 = Color(red: 0.61, green: 0.36, blue: 1.0)      // #9B5CFF
    static let night = Color(red: 0.43, green: 0.48, blue: 1.0)      // #6E7BFF
    static let card = Color(red: 0.11, green: 0.11, blue: 0.12)      // #1C1C1E
    static let secondary = Color(red: 0.56, green: 0.56, blue: 0.58) // #8E8E93
    static let sun = Color(red: 1.0, green: 0.89, blue: 0.63)

    static func color(_ kind: SolarEvent.Kind) -> Color {
        kind == .sunrise ? dawn : dusk
    }

    static func gradient(_ kind: SolarEvent.Kind) -> LinearGradient {
        LinearGradient(
            colors: kind == .sunrise ? [dawn, dawn2] : [dusk, dusk2],
            startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
