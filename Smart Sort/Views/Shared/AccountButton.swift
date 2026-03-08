//
//  AccountButton.swift
//  Smart Sort
//

import SwiftUI

struct AccountButton: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject private var appRouter: AppRouter
    private let theme = TrashTheme()

    var body: some View {
        Button {
            appRouter.presentAccount()
        } label: {
            Image(systemName: authVM.isAnonymous ? "person.fill" : "person.crop.circle")
                .font(.system(size: 18, weight: .semibold))
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
