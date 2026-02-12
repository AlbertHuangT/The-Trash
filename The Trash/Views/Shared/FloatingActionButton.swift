//
//  FloatingActionButton.swift
//  The Trash
//
//  Extracted from CommunityTabView.swift
//

import SwiftUI

struct FloatingActionButton: View {
    let icon: String
    let action: () -> Void

    @State private var isPressed = false
    @Environment(\.trashTheme) private var theme

    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            action()
        }) {
            let buttonSize = theme.spacing.xxl
            ZStack {
                Circle()
                    .fill(theme.gradients.accent)
                    .frame(width: buttonSize, height: buttonSize)
                    .shadow(color: theme.accents.blue.opacity(0.35), radius: theme.spacing.md, x: theme.spacing.sm, y: theme.spacing.sm)
                    .shadow(color: theme.shadows.light, radius: theme.spacing.md, x: -theme.spacing.sm * 0.5, y: -theme.spacing.sm * 0.5)

                Image(systemName: icon)
                    .font(theme.typography.button)
                    .foregroundColor(.white)
            }
        }
        .scaleEffect(isPressed ? 0.9 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
    }
}
