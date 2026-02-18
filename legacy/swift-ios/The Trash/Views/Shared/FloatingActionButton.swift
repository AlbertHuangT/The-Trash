//
//  FloatingActionButton.swift
//  The Trash
//

import SwiftUI

struct FloatingActionButton: View {
    let icon: String
    let action: () -> Void
    @Environment(\.trashTheme) private var theme

    var body: some View {
        TrashTapArea(haptics: true, action: action) {
            ZStack {
                Color.clear
                    .frame(width: theme.spacing.xxl * 1.5, height: theme.spacing.xxl * 1.5)
                    .trashCard(cornerRadius: theme.spacing.xxl)

                TrashIcon(systemName: icon)
                    .font(.title2.bold())
                    .trashOnAccentForeground()
            }
        }
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
}
