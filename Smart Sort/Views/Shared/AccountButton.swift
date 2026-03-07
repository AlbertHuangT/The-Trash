//
//  AccountButton.swift
//  Smart Sort
//

import SwiftUI

struct AccountButton: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject private var appRouter: AppRouter

    var body: some View {
        Button {
            appRouter.presentAccount()
        } label: {
            Image(systemName: authVM.isAnonymous ? "person.fill" : "person.crop.circle")
                .font(.title3)
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Account")
    }
}
