//
//  AccountButton.swift
//  The Trash
//

import SwiftUI

// ✨ 在本地重新定义以确保类型推断成功
private struct ShowAccountSheetKey: EnvironmentKey {
    static let defaultValue: Binding<Bool> = .constant(false)
}

extension EnvironmentValues {
    var showAccountSheet: Binding<Bool> {
        get { self[ShowAccountSheetKey.self] }
        set { self[ShowAccountSheetKey.self] = newValue }
    }
}

// MARK: - Account Button
struct AccountButton: View {
    @Environment(\.showAccountSheet) private var showAccountSheet
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.trashTheme) private var theme

    var body: some View {
        Button {
            showAccountSheet.wrappedValue = true
        } label: {
            ZStack {
                Color.clear
                    .frame(width: 42, height: 42)
                    .trashCard(cornerRadius: 21)

                if theme.visualStyle == .ecoPaper {
                    StampedIcon(
                        systemName: authVM.isAnonymous ? "person.fill" : "person.crop.circle.fill",
                        size: 22,
                        weight: .bold,
                        color: theme.accents.blue
                    )
                } else {
                    TrashIcon(systemName: authVM.isAnonymous ? "person.fill" : "person.crop.circle.fill")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(theme.accents.blue)
                }
            }
        }
    }
}
