//
//  View+BadgeStyle.swift
//  Smart Sort
//

import SwiftUI

extension View {
    func badgeStyle(foreground: Color = .white, background: Color) -> some View {
        self
            .font(.caption.weight(.semibold))
            .foregroundColor(foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(background)
            )
    }
}
