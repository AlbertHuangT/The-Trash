//
//  AccountButton.swift
//  Smart Sort
//

import SwiftUI

struct AccountButton: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject private var appRouter: AppRouter
    @Environment(\.trashTheme) private var theme

    var body: some View {
        Button {
            appRouter.presentAccount()
        } label: {
            Image(systemName: authVM.isAnonymous ? "person.fill" : "person.crop.circle")
                .font(theme.typography.button)
                .foregroundColor(theme.palette.textSecondary)
                .frame(
                    width: theme.layout.toolbarHitTarget,
                    height: theme.layout.toolbarHitTarget
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Account")
    }
}
