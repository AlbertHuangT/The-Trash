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
               .font(theme.typography.button)
               .foregroundColor(foreground)
               .frame(
                   width: theme.components.iconButtonSize,
                   height: theme.components.iconButtonSize
               )
               .background {
                   Circle()
                       .fill(background)
                       .shadow(color: Color.black.opacity(0.035), radius: 8, x: 0, y: 3)
               }
               .overlay {
                   Circle().stroke(borderColor, lineWidth: borderWidth)
               }
       }
       .buttonStyle(.plain)
       .accessibilityLabel(Text(icon.replacingOccurrences(of: ".", with: " ")))
   }

   private var foreground: Color {
       isActive ? theme.onAccentForeground : theme.palette.textSecondary
   }

   private var background: Color {
       if isActive {
           return activeColor ?? theme.accents.blue
       }
       return theme.surfaceBackground
   }

   private var borderColor: Color {
       return theme.palette.textPrimary.opacity(0.2)
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
       HStack(spacing: theme.spacing.sm) {
           if let icon {
               StampedIcon(systemName: icon, size: 12, weight: .semibold, color: iconColor)
           }
           Text(title)
               .trashTextRole(.caption, color: foreground, compact: true)
               .fontWeight(.semibold)
       }
       .padding(.horizontal, theme.layout.compactControlHorizontalInset)
       .frame(minHeight: action == nil ? theme.components.compactControlHeight : theme.components.pillHeight)
       .background {
           RoundedRectangle(cornerRadius: theme.corners.pill, style: .continuous)
               .fill(background)
               .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
       }
       .overlay {
           RoundedRectangle(cornerRadius: theme.corners.pill, style: .continuous)
               .stroke(borderColor, lineWidth: isSelected ? 0 : 1)
       }
   }

   private var selectedColor: Color {
       color ?? theme.accents.blue
   }

   private var iconColor: Color {
       isSelected ? theme.onAccentForeground : (color ?? theme.palette.textSecondary)
   }

   private var foreground: Color {
       isSelected ? theme.onAccentForeground : theme.palette.textPrimary
   }

   private var background: Color {
       if isSelected {
           return selectedColor
       }
       return theme.surfaceBackground
   }

   private var borderColor: Color {
       return theme.palette.textPrimary.opacity(0.18)
   }
}

// MARK: - Search Field

struct TrashSearchField: View {
   let placeholder: String
   @Binding var text: String
   var showClearButton: Bool = true

   @Environment(\.trashTheme) private var theme

   var body: some View {
       HStack(spacing: theme.layout.rowContentSpacing) {
           TrashIcon(systemName: "magnifyingglass")
               .font(theme.typography.button)
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
                       .font(theme.typography.button)
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
           .padding(.horizontal, theme.layout.inputHorizontalInset)
           .frame(minHeight: theme.components.inputHeight)
           .background {
               background
           }
           .overlay {
               RoundedRectangle(cornerRadius: radius, style: .continuous)
                   .stroke(borderColor, lineWidth: 1)
           }
   }

   private var radius: CGFloat { cornerRadius ?? theme.layout.standardCardCornerRadius }

   @ViewBuilder
   private var background: some View {
       let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
       shape
           .fill(theme.surfaceBackground)
   }

   private var borderColor: Color {
       return theme.palette.divider.opacity(0.85)
   }
}

// MARK: - Section Title

struct TrashSectionTitle: View {
   let title: String
   @Environment(\.trashTheme) private var theme

   var body: some View {
       Text(title)
           .trashTextRole(.kicker)
           .frame(maxWidth: .infinity, alignment: .leading)
   }
}

// MARK: - Text Button

struct TrashTextButton: View {
   enum Variant {
       case standard
       case accent
       case destructive
   }

   let title: String
   var color: Color? = nil
   var variant: Variant = .standard
   let action: () -> Void
   @Environment(\.trashTheme) private var theme

   var body: some View {
        Button(action: action) {
            Text(title)
               .trashTextRole(.button, color: resolvedColor, compact: true)
               .fontWeight(.medium)
               .padding(.horizontal, theme.layout.inlineButtonHorizontalInset)
               .frame(
                   minWidth: theme.components.minimumHitTarget,
                   minHeight: theme.components.minimumHitTarget,
                   alignment: .center
               )
       }
       .buttonStyle(.plain)
   }

   private var resolvedColor: Color {
       if let color { return color }
       switch variant {
       case .standard: return theme.palette.textSecondary
       case .accent: return theme.accents.blue
       case .destructive: return theme.semanticDanger
       }
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
       HStack(spacing: theme.layout.rowContentSpacing) {
           TrashIcon(systemName: icon)
               .font(theme.typography.button)
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
       .padding(.vertical, theme.spacing.xs)
       .trashInputStyle(cornerRadius: theme.layout.standardCardCornerRadius)
       .overlay(
           RoundedRectangle(cornerRadius: theme.layout.standardCardCornerRadius)
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
           .padding(theme.spacing.xs)
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
       .frame(minHeight: theme.components.minimumHitTarget)
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
       .frame(minHeight: theme.components.minimumHitTarget)
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
           .frame(minHeight: theme.components.minimumHitTarget)
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
       .frame(minHeight: theme.components.minimumHitTarget)
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
       .frame(minHeight: theme.components.minimumHitTarget)
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
           VStack(spacing: theme.layout.sheetActionSpacing) {
               Text(title)
                   .trashTextRole(.title)
                   .multilineTextAlignment(.center)

               Text(message)
                   .trashTextRole(.body, color: theme.palette.textSecondary)
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
                }
            }
           .padding(theme.components.sheetPadding)
           .trashSheetSurface()
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
           VStack(spacing: theme.layout.sheetActionSpacing) {
               Text(title)
                   .trashTextRole(.title)
                   .multilineTextAlignment(.center)

               Text(message)
                   .trashTextRole(.body, color: theme.palette.textSecondary)
                   .multilineTextAlignment(.center)

               TrashButton(baseColor: confirmColor ?? theme.accents.blue, action: onConfirm) {
                   Text(confirmTitle)
                       .frame(maxWidth: .infinity)
               }

               TrashTextButton(title: cancelTitle) {
                   if let onCancel {
                       onCancel()
                   } else {
                       dismiss()
                   }
               }
           }
           .padding(theme.components.sheetPadding)
           .trashSheetSurface()
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
           VStack(spacing: theme.layout.sheetActionSpacing) {
               Text(title)
                   .trashTextRole(.title)
                   .multilineTextAlignment(.center)

               Text(message)
                   .trashTextRole(.body, color: theme.palette.textSecondary)
                   .multilineTextAlignment(.center)

               TrashFormTextField(
                   title: placeholder,
                   text: $text,
                   textInputAutocapitalization: .words
               )

               HStack(spacing: theme.layout.elementSpacing) {
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
                   }
                   .frame(maxWidth: .infinity)
                   .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
               }
           }
           .padding(theme.components.sheetPadding)
           .trashSheetSurface()
       }
   }
}

private struct TrashSheetSurfaceModifier: ViewModifier {
   @Environment(\.trashTheme) private var theme

   func body(content: Content) -> some View {
       content
           .background(
               RoundedRectangle(cornerRadius: theme.layout.prominentCardCornerRadius, style: .continuous)
                   .fill(theme.surfaceBackground)
                   .overlay(
                       RoundedRectangle(cornerRadius: theme.layout.prominentCardCornerRadius, style: .continuous)
                           .stroke(theme.palette.divider.opacity(0.85), lineWidth: 1)
                   )
                   .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
           )
           .padding(.horizontal, theme.layout.sheetEdgeInset)
   }
}

extension View {
   func trashSheetSurface() -> some View {
       modifier(TrashSheetSurfaceModifier())
   }
}
