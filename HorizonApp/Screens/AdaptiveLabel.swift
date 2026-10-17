import SwiftUI
import WatchKit

/// Sizes for the small cases (40 to 44 mm), where the arc, the times and the pill share
/// much less height.
enum Layout {
    static let isCompact = WKInterfaceDevice.current().screenBounds.width < 190

    static func size(_ regular: CGFloat, compact: CGFloat) -> CGFloat {
        isCompact ? compact : regular
    }
}

/// Shows a label, or its `.short` variant from the String Catalog when the long one does not fit
/// (German "Untergang" for "Sonnenuntergang").
struct AdaptiveLabel: View {
    let key: String

    init(_ key: String) {
        self.key = key
    }

    var body: some View {
        // Plain strings on purpose: `LocalizedStringKey("\(key).short")` would be read as the
        // format key "%@.short".
        ViewThatFits(in: .horizontal) {
            Text(L10n.string(key))
                .lineLimit(1)
            Text(L10n.string(key + ".short"))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

/// Two labels at the ends of a row. Both switch to their short variant together, so the row
/// never mixes "Sonnenaufgang" with "Untergang".
struct AdaptiveLabelPair<Leading: View, Trailing: View>: View {
    let leading: String
    let trailing: String
    @ViewBuilder let leadingStyle: (Text) -> Leading
    @ViewBuilder let trailingStyle: (Text) -> Trailing

    var body: some View {
        ViewThatFits(in: .horizontal) {
            row(leading, trailing)
            row(leading + ".short", trailing + ".short")
                .minimumScaleFactor(0.7)
        }
    }

    private func row(_ leading: String, _ trailing: String) -> some View {
        HStack(spacing: 10) {
            leadingStyle(Text(L10n.string(leading))).lineLimit(1)
            Spacer(minLength: 0)
            trailingStyle(Text(L10n.string(trailing))).lineLimit(1)
        }
    }
}

extension View {
    /// Page title in the mockup's place: top leading, on the clock's row.
    func pageTitle(_ title: Text) -> some View {
        toolbar {
            ToolbarItem(placement: .topBarLeading) {
                title
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.dawn)
                    .lineLimit(1)
                    .fixedSize()
                    .accessibilityAddTraits(.isHeader)
            }
        }
    }
}
