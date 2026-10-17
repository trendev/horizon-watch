import HorizonCore
import SwiftUI

/// Second page: today and the six days after it.
struct WeekView: View {
    @Environment(AppModel.self) private var model
    @Binding var page: Int
    /// The time under a long press, offered "Skip this day" or "Restore".
    @State private var selected: SolarEvent?

    var body: some View {
        List {
            ForEach(Array((model.plan?.week ?? []).enumerated()), id: \.element.day) { index, day in
                row(day, isToday: index == 0)
                    .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
            }
        }
        .pageTitle(Text(L10n.format("week.title", 7)))
        .confirmationDialog(
            selected.map { Fmt.time($0.date, in: model.timeZone) } ?? "",
            isPresented: Binding(get: { selected != nil }, set: { if !$0 { selected = nil } }),
            titleVisibility: .visible
        ) {
            if let event = selected {
                Button(model.settings.skipped.contains(event.id) ? "week.restore" : "week.skip") {
                    model.toggleSkip(event)
                }
                .accessibilityIdentifier("week.toggleSkip")
            }
        }
    }

    private func row(_ day: SolarDay, isToday: Bool) -> some View {
        HStack(spacing: 4) {
            Button {
                // Shows that day on the arc.
                model.viewedDay = isToday ? nil : day
                page = 0
            } label: {
                Group {
                    if isToday {
                        Text("week.today").foregroundStyle(Theme.dawn)
                    } else {
                        Text(Fmt.weekday(day.day, in: model.timeZone))
                    }
                }
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("week.day.\(day.day.iso)")

            time(.sunrise, day: day)
            time(.sunset, day: day)
        }
    }

    @ViewBuilder
    private func time(_ kind: SolarEvent.Kind, day: SolarDay) -> some View {
        if let event = day.events.first(where: { $0.kind == kind }) {
            let skipped = model.settings.skipped.contains(event.id)
            let rings = model.settings.rings(event)
            HStack(spacing: 2) {
                Image(systemName: kind == .sunrise ? "sunrise.fill" : "sunset.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(rings ? Theme.color(kind) : Theme.secondary)
                Text(Fmt.time(event.date, in: model.timeZone))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .strikethrough(skipped)
                    .foregroundStyle(rings ? .white : Theme.secondary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(minHeight: 36)
            .contentShape(Rectangle())
            .onLongPressGesture { selected = event }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("week.\(event.id)")
            .accessibilityValue(skipped ? L10n.string("week.skipped") : "")
            .accessibilityAction(named: Text(skipped ? "week.restore" : "week.skip")) {
                model.toggleSkip(event)
            }
        } else {
            Text(verbatim: "–")
                .foregroundStyle(Theme.secondary)
                .frame(minWidth: 40)
        }
    }
}
