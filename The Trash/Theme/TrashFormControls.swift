import SwiftUI

// MARK: - Icon Button

struct TrashIconButton: View {
    let icon: String
    var isActive: Bool = false
    var activeColor: Color? = nil
    let action: () -> Void

    @Environment(\.trashTheme) private var theme

    var body: some View {
        Button(action: action) {
            TrashIcon(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(foreground)
                .frame(width: 34, height: 34)
                .background {
                    Circle().fill(background)
                }
                .overlay {
                    Circle().stroke(borderColor, lineWidth: borderWidth)
                }
        }
        .buttonStyle(.plain)
    }

    private var foreground: Color {
        isActive ? theme.onAccentForeground : theme.palette.textSecondary
    }

    private var background: Color {
        if isActive {
            return activeColor ?? theme.accents.blue
        }
        switch theme.visualStyle {
        case .neumorphic:
            return theme.palette.background
        case .vibrantGlass:
            return theme.palette.card.opacity(0.82)
        case .ecoPaper:
            return theme.palette.card.opacity(0.98)
        }
    }

    private var borderColor: Color {
        switch theme.visualStyle {
        case .neumorphic:
            return theme.palette.divider.opacity(0.35)
        case .vibrantGlass:
            return theme.accents.blue.opacity(0.35)
        case .ecoPaper:
            return theme.palette.textPrimary.opacity(0.2)
        }
    }

    private var borderWidth: CGFloat {
        isActive ? 0 : 1
    }
}

// MARK: - Pill

struct TrashPill: View {
    let title: String
    let icon: String?
    var color: Color? = nil
    var isSelected: Bool = false
    let action: (() -> Void)?

    @Environment(\.trashTheme) private var theme

    init(
        title: String,
        icon: String? = nil,
        color: Color? = nil,
        isSelected: Bool = false,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.icon = icon
        self.color = color
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Group {
            if let action {
                Button(action: action) {
                    pillBody
                }
                .buttonStyle(.plain)
            } else {
                pillBody
            }
        }
    }

    private var pillBody: some View {
        HStack(spacing: 6) {
            if let icon {
                if theme.visualStyle == .ecoPaper {
                    StampedIcon(systemName: icon, size: 12, weight: .semibold, color: foreground)
                } else {
                    TrashIcon(systemName: icon)
                        .font(.caption)
                        .foregroundColor(foreground)
                }
            }
            Text(title)
                .font(theme.typography.caption)
                .fontWeight(.semibold)
                .foregroundColor(foreground)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background {
            RoundedRectangle(cornerRadius: theme.corners.pill, style: .continuous)
                .fill(background)
        }
        .overlay {
            RoundedRectangle(cornerRadius: theme.corners.pill, style: .continuous)
                .stroke(borderColor, lineWidth: isSelected ? 0 : 1)
        }
    }

    private var selectedColor: Color {
        color ?? theme.accents.blue
    }

    private var foreground: Color {
        isSelected ? theme.onAccentForeground : (color ?? theme.palette.textSecondary)
    }

    private var background: Color {
        if isSelected {
            return selectedColor
        }
        switch theme.visualStyle {
        case .neumorphic:
            return theme.palette.background
        case .vibrantGlass:
            return theme.palette.card.opacity(0.8)
        case .ecoPaper:
            return theme.palette.card.opacity(0.98)
        }
    }

    private var borderColor: Color {
        switch theme.visualStyle {
        case .neumorphic:
            return theme.palette.divider.opacity(0.45)
        case .vibrantGlass:
            return theme.accents.blue.opacity(0.32)
        case .ecoPaper:
            return theme.palette.textPrimary.opacity(0.18)
        }
    }
}

// MARK: - Search Field

struct TrashSearchField: View {
    let placeholder: String
    @Binding var text: String
    var showClearButton: Bool = true

    @Environment(\.trashTheme) private var theme

    var body: some View {
        HStack(spacing: 10) {
            TrashIcon(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.palette.textSecondary)

            TextField(placeholder, text: $text)
                .foregroundColor(theme.palette.textPrimary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if showClearButton && !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    TrashIcon(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(theme.palette.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .trashInputStyle()
    }
}

// MARK: - Input Surface Modifier

struct TrashInputSurface: ViewModifier {
    @Environment(\.trashTheme) private var theme
    let cornerRadius: CGFloat?

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background {
                background
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            }
    }

    private var radius: CGFloat { cornerRadius ?? theme.corners.medium }

    @ViewBuilder
    private var background: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        switch theme.visualStyle {
        case .neumorphic:
            shape
                .fill(theme.palette.background)
                .shadow(color: theme.shadows.dark.opacity(0.5), radius: 4, x: 2, y: 2)
                .shadow(color: theme.shadows.light.opacity(0.6), radius: 3, x: -2, y: -2)
        case .vibrantGlass:
            shape
                .fill(theme.palette.card.opacity(0.82))
                .overlay(
                    LinearGradient(
                        colors: [
                            theme.accents.blue.opacity(0.1), theme.accents.purple.opacity(0.1),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(shape)
                )
        case .ecoPaper:
            shape
                .fill(theme.palette.card)
                .overlay(
                    PaperTextureView(baseColor: theme.palette.card).clipShape(shape).opacity(0.2)
                )
                .overlay(
                    shape
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                        .padding(1)
                )
        }
    }

    private var borderColor: Color {
        switch theme.visualStyle {
        case .neumorphic:
            return theme.palette.divider.opacity(0.35)
        case .vibrantGlass:
            return theme.accents.blue.opacity(0.32)
        case .ecoPaper:
            return theme.palette.divider.opacity(0.85)
        }
    }
}

// MARK: - Section Title

struct TrashSectionTitle: View {
    let title: String
    @Environment(\.trashTheme) private var theme

    var body: some View {
        Text(title)
            .font(theme.typography.subheadline)
            .foregroundColor(theme.palette.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Text Button

struct TrashTextButton: View {
    let title: String
    var color: Color? = nil
    let action: () -> Void
    @Environment(\.trashTheme) private var theme

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(theme.typography.subheadline)
                .fontWeight(.medium)
                .foregroundColor(color ?? theme.palette.textSecondary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Form Controls

struct TrashFormTextField: View {
    let title: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var textInputAutocapitalization: TextInputAutocapitalization = .never

    var body: some View {
        TextField(title, text: $text)
            .keyboardType(keyboardType)
            .textInputAutocapitalization(textInputAutocapitalization)
            .autocorrectionDisabled()
            .trashInputStyle()
    }
}

struct TrashFormSecureField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        SecureField(title, text: $text)
            .trashInputStyle()
    }
}

struct TrashIconInputField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var textInputAutocapitalization: TextInputAutocapitalization = .never
    @FocusState private var isFocused: Bool
    @Environment(\.trashTheme) private var theme

    var body: some View {
        HStack(spacing: 14) {
            TrashIcon(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isFocused ? theme.accents.blue : theme.palette.textSecondary)
                .frame(width: 24)

            if isSecure {
                SecureField(placeholder, text: $text)
                    .foregroundColor(theme.palette.textPrimary)
                    .focused($isFocused)
            } else {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(textInputAutocapitalization)
                    .autocorrectionDisabled()
                    .foregroundColor(theme.palette.textPrimary)
                    .focused($isFocused)
            }
        }
        .padding(16)
        .trashInputStyle(cornerRadius: 14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isFocused ? theme.accents.blue.opacity(0.5) : Color.clear, lineWidth: 2)
        )
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

struct TrashFormTextEditor: View {
    @Binding var text: String
    var minHeight: CGFloat = 80
    @Environment(\.trashTheme) private var theme

    var body: some View {
        TextEditor(text: $text)
            .frame(minHeight: minHeight)
            .padding(2)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .foregroundColor(theme.palette.textPrimary)
            .trashInputStyle()
    }
}

struct TrashFormToggle: View {
    let title: String
    @Binding var isOn: Bool
    @Environment(\.trashTheme) private var theme

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(title)
                .font(theme.typography.subheadline)
                .foregroundColor(theme.palette.textPrimary)
        }
    }
}

struct TrashFormStepper: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    var step: Int = 1
    @Environment(\.trashTheme) private var theme

    var body: some View {
        Stepper(value: $value, in: range, step: step) {
            Text("\(title): \(value)")
                .font(theme.typography.subheadline)
                .foregroundColor(theme.palette.textPrimary)
        }
    }
}

struct TrashFormDatePicker: View {
    let title: String
    @Binding var selection: Date
    var range: PartialRangeFrom<Date> = Date()...
    @Environment(\.trashTheme) private var theme

    var body: some View {
        DatePicker(title, selection: $selection, in: range)
            .font(theme.typography.subheadline)
            .foregroundColor(theme.palette.textPrimary)
    }
}

// MARK: - Picker Controls

struct TrashPickerOption<Value: Hashable>: Identifiable {
    let value: Value
    let title: String
    let icon: String?

    var id: AnyHashable { AnyHashable(value) }
}

struct TrashFormPicker<Value: Hashable>: View {
    let title: String
    @Binding var selection: Value
    let options: [TrashPickerOption<Value>]
    var style: PickerStyleKind = .menu
    @Environment(\.trashTheme) private var theme

    enum PickerStyleKind {
        case menu
        case wheel
    }

    var body: some View {
        Group {
            if style == .wheel {
                Picker(title, selection: $selection) {
                    pickerOptions
                }
                .pickerStyle(.wheel)
            } else {
                Picker(title, selection: $selection) {
                    pickerOptions
                }
                .pickerStyle(.menu)
            }
        }
        .tint(theme.accents.blue)
        .font(theme.typography.subheadline)
        .foregroundColor(theme.palette.textPrimary)
    }

    @ViewBuilder
    private var pickerOptions: some View {
        ForEach(options) { option in
            if let icon = option.icon {
                TrashLabel(option.title, icon: icon).tag(option.value)
            } else {
                Text(option.title).tag(option.value)
            }
        }
    }
}

struct TrashOptionalPickerOption<Value: Hashable>: Identifiable {
    let value: Value?
    let title: String

    var id: AnyHashable { AnyHashable(value) }
}

struct TrashOptionalFormPicker<Value: Hashable>: View {
    let title: String
    @Binding var selection: Value?
    let options: [TrashOptionalPickerOption<Value>]
    @Environment(\.trashTheme) private var theme

    var body: some View {
        Picker(title, selection: $selection) {
            ForEach(options) { option in
                Text(option.title).tag(option.value)
            }
        }
        .pickerStyle(.menu)
        .tint(theme.accents.blue)
        .font(theme.typography.subheadline)
        .foregroundColor(theme.palette.textPrimary)
    }
}

// MARK: - Sheet Components

struct TrashNoticeSheet: View {
    let title: String
    let message: String
    var buttonTitle: String = "OK"
    var buttonColor: Color? = nil
    let onClose: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.trashTheme) private var theme

    init(
        title: String,
        message: String,
        buttonTitle: String = "OK",
        buttonColor: Color? = nil,
        onClose: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.buttonTitle = buttonTitle
        self.buttonColor = buttonColor
        self.onClose = onClose
    }

    var body: some View {
        ZStack {
            ThemeBackground()
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Text(title)
                    .font(theme.typography.title)
                    .foregroundColor(theme.palette.textPrimary)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(theme.typography.subheadline)
                    .foregroundColor(theme.palette.textSecondary)
                    .multilineTextAlignment(.center)

                TrashButton(
                    baseColor: buttonColor ?? theme.accents.blue,
                    action: {
                        if let onClose {
                            onClose()
                        } else {
                            dismiss()
                        }
                    }
                ) {
                    Text(buttonTitle)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            }
            .padding(22)
            .trashCard(cornerRadius: 20)
            .padding(.horizontal, 20)
        }
    }
}

struct TrashConfirmSheet: View {
    let title: String
    let message: String
    let confirmTitle: String
    var confirmColor: Color? = nil
    let onConfirm: () -> Void
    var cancelTitle: String = "Cancel"
    let onCancel: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.trashTheme) private var theme

    init(
        title: String,
        message: String,
        confirmTitle: String,
        confirmColor: Color? = nil,
        onConfirm: @escaping () -> Void,
        cancelTitle: String = "Cancel",
        onCancel: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.confirmTitle = confirmTitle
        self.confirmColor = confirmColor
        self.onConfirm = onConfirm
        self.cancelTitle = cancelTitle
        self.onCancel = onCancel
    }

    var body: some View {
        ZStack {
            ThemeBackground()
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Text(title)
                    .font(theme.typography.title)
                    .foregroundColor(theme.palette.textPrimary)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(theme.typography.subheadline)
                    .foregroundColor(theme.palette.textSecondary)
                    .multilineTextAlignment(.center)

                TrashButton(baseColor: confirmColor ?? theme.accents.blue, action: onConfirm) {
                    Text(confirmTitle)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }

                TrashTextButton(title: cancelTitle) {
                    if let onCancel {
                        onCancel()
                    } else {
                        dismiss()
                    }
                }
            }
            .padding(22)
            .trashCard(cornerRadius: 20)
            .padding(.horizontal, 20)
        }
    }
}

struct TrashTextInputSheet: View {
    let title: String
    let message: String
    let placeholder: String
    @Binding var text: String
    var confirmTitle: String = "Save"
    let onConfirm: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.trashTheme) private var theme

    var body: some View {
        ZStack {
            ThemeBackground()
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Text(title)
                    .font(theme.typography.title)
                    .foregroundColor(theme.palette.textPrimary)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(theme.typography.subheadline)
                    .foregroundColor(theme.palette.textSecondary)
                    .multilineTextAlignment(.center)

                TrashFormTextField(
                    title: placeholder,
                    text: $text,
                    textInputAutocapitalization: .words
                )

                HStack(spacing: 10) {
                    TrashTextButton(title: "Cancel") {
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)

                    TrashButton(
                        baseColor: theme.accents.blue,
                        action: {
                            onConfirm(text)
                        }
                    ) {
                        Text(confirmTitle)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(22)
            .trashCard(cornerRadius: 20)
            .padding(.horizontal, 20)
        }
    }
}
