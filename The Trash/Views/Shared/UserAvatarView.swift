//
//  UserAvatarView.swift
//  The Trash
//

import SwiftUI

struct UserAvatarView: View {
    let name: String
    var color: Color = .blue
    var size: CGFloat = 44

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .overlay(
                Text(String(name.prefix(1)))
                    .font(.headline)
                    .foregroundColor(.white)
            )
    }
}
