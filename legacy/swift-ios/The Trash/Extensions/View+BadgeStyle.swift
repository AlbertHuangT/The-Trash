//
//  View+BadgeStyle.swift
//  The Trash
//

import SwiftUI

extension View {
    func badgeStyle(foreground: Color = .white, background: Color) -> some View {
        self
            .font(.caption)
            .foregroundColor(foreground)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(background)
            .cornerRadius(4)
    }
}
