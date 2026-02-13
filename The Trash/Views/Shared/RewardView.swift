//
//  RewardView.swift
//  The Trash
//
//  Created by Albert Huang on 2/4/26.
//


import SwiftUI

struct RewardView: View {
    var body: some View {
        NavigationView {
            VStack {
                TrashIcon(systemName: "gift.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)
                Text("Rewards Coming Soon").font(.headline)
            }.navigationTitle("Rewards")
        }
    }
}