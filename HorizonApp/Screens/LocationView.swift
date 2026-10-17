import HorizonCore
import SwiftUI

/// Where the sun times are computed for. Everything stays on the watch.
struct LocationView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                Image(systemName: "location.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.dawn)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Theme.dawn.opacity(0.2)))

                if let location = model.location {
                    Text(Fmt.place(city: model.placeName, countryCode: location.countryCode))
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("location.place")
                    Text(Fmt.coordinates(location.coordinates))
                        .font(.caption2)
                        .foregroundStyle(Theme.secondary)
                    chip(location)
                }

                if model.isLocationDenied {
                    Text("location.denied")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                } else {
                    Button {
                        Task { await model.refreshLocation() }
                    } label: {
                        if model.isLocating {
                            ProgressView()
                        } else {
                            Text("location.refresh")
                        }
                    }
                    .disabled(model.isLocating)
                    .accessibilityIdentifier("location.refresh")
                }

                NavigationLink("location.chooseCity") {
                    CityPickerView()
                }
                .accessibilityIdentifier("location.chooseCity")

                Text("location.privacy")
                    .font(.caption2)
                    .foregroundStyle(Theme.secondary)
                    .multilineTextAlignment(.center)
                // Attribution required by the licence of the bundled city list.
                Text(verbatim: "GeoNames · CC BY 4.0")
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.secondary.opacity(0.7))
            }
            .padding(.horizontal, 6)
        }
        .navigationTitle("settings.location")
    }

    /// "GPS · 12 min ago" after a recent fix, "Last known position" otherwise.
    @ViewBuilder
    private func chip(_ location: StoredLocation) -> some View {
        if location.source == .gps {
            let now = model.now()
            let isFresh = now.timeIntervalSince(location.timestamp) < 3600
            HStack(spacing: 4) {
                Circle()
                    .fill(isFresh ? .green : Theme.secondary)
                    .frame(width: 6, height: 6)
                Text(isFresh
                    ? L10n.format("location.updated", Fmt.relative(location.timestamp, to: now))
                    : L10n.string("location.lastKnown"))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(isFresh ? .green : Theme.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill((isFresh ? Color.green : Theme.secondary).opacity(0.18)))
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("location.status")
        }
    }
}
