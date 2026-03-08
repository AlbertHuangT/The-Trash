import SwiftUI

// MARK: - Segmented Control

struct TrashSegmentOption<Value: Hashable>: Identifiable {
    let value: Value
    let title: String
    let icon: String?

    var id: AnyHashable { AnyHashable(value) }
}

struct TrashTabItem<Value: Hashable>: Identifiable {
    let value: Value
    let title: String
    let icon: String

    var id: AnyHashable { AnyHashable(value) }
}

struct TrashSegmentedControl<Value: Hashable>: View {
    let options: [TrashSegmentOption<Value>]
    @Binding var selection: Value
    private let theme = TrashTheme()

    var body: some View {
        Picker("", selection: $selection) {
            ForEach(options) { option in
                Label(option.title, systemImage: option.icon ?? "circle")
                    .tag(option.value)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(minHeight: theme.components.segmentedControlHeight)
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: theme.layout.prominentCardCornerRadius, style: .continuous)
                .fill(theme.surfaceBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: theme.layout.prominentCardCornerRadius, style: .continuous)
                        .stroke(theme.palette.divider.opacity(0.75), lineWidth: 1)
                )
        )
    }
}
