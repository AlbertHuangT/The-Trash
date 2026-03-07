import SwiftUI

// MARK: - Icon Button

struct TrashIconButton: View {
   let icon: String
   var isActive: Bool = false
   var activeColor: Color? = nil
   let action: () -> Void

   private let theme = TrashTheme()

   var body: some View {
       Button(action: action) {
           TrashIcon(systemName: icon)
               .font(.system(size: 14, weight: .semibold))
               .foregroundColor(foreground)
               .frame(width: 38, height: 38)
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

   private let theme = TrashTheme()

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
               StampedIcon(systemName: icon, size: 12, weight: .semibold, color: iconColor)
           }
           Text(title)
               .font(theme.typography.caption)
               .fontWeight(.semibold)
               .foregroundColor(foreground)
               .lineLimit(1)
       }
       .padding(.horizontal, 12)
       .padding(.vertical, 8)
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

   private let theme = TrashTheme()

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
   private let theme = TrashTheme()
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
   private let theme = TrashTheme()

   var body: some View {
       Text(title)
           .font(.footnote.weight(.semibold))
           .foregroundColor(theme.palette.textSecondary)
           .frame(maxWidth: .infinity, alignment: .leading)
           .textCase(.uppercase)
           .tracking(0.5)
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
   private let theme = TrashTheme()

   var body: some View {
       Button(action: action) {
           Text(title)
               .font(theme.typography.subheadline)
               .fontWeight(.medium)
               .foregroundColor(resolvedColor)
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
   private let theme = TrashTheme()

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
   private let theme = TrashTheme()

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
   private let theme = TrashTheme()

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
   private let theme = TrashTheme()

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
   private let theme = TrashTheme()

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
   private let theme = TrashTheme()

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
   private let theme = TrashTheme()

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
   private let theme = TrashTheme()

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
           .background(
               RoundedRectangle(cornerRadius: 20, style: .continuous)
                   .fill(theme.surfaceBackground)
                   .overlay(
                       RoundedRectangle(cornerRadius: 20, style: .continuous)
                           .stroke(theme.palette.divider.opacity(0.85), lineWidth: 1)
                   )
                   .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
           )
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
   private let theme = TrashTheme()

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
           .background(
               RoundedRectangle(cornerRadius: 20, style: .continuous)
                   .fill(theme.surfaceBackground)
                   .overlay(
                       RoundedRectangle(cornerRadius: 20, style: .continuous)
                           .stroke(theme.palette.divider.opacity(0.85), lineWidth: 1)
                   )
                   .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
           )
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
   private let theme = TrashTheme()

   var body: some View {
       ZStack {
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
           .background(
               RoundedRectangle(cornerRadius: 20, style: .continuous)
                   .fill(theme.surfaceBackground)
                   .overlay(
                       RoundedRectangle(cornerRadius: 20, style: .continuous)
                           .stroke(theme.palette.divider.opacity(0.85), lineWidth: 1)
                   )
                   .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
           )
           .padding(.horizontal, 20)
       }
   }
}
