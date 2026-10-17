import HorizonCore
import SwiftUI

/// Offline city search, used when location is refused.
struct CityPickerView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    var onPick: (() -> Void)?

    var body: some View {
        List {
            TextField("location.chooseCity", text: $query)
                .accessibilityIdentifier("city.search")
            ForEach(model.cities?.search(prefix: query, limit: 30) ?? [], id: \.self) { city in
                Button {
                    model.choose(city)
                    if let onPick { onPick() } else { dismiss() }
                } label: {
                    VStack(alignment: .leading) {
                        Text(city.name)
                        Text(Locale.current.localizedString(forRegionCode: city.countryCode) ?? city.countryCode)
                            .font(.caption2)
                            .foregroundStyle(Theme.secondary)
                    }
                }
            }
        }
        .navigationTitle("location.chooseCity")
    }
}
