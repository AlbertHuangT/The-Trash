//
//  RewardView.swift
//  Smart Sort
//
//  Created by Albert Huang on 2/4/26.
//


import SwiftUI

struct RewardView: View {
    var body: some View {
        EmptyStateView(
            icon: "gift.fill",
            title: "Rewards Coming Soon",
            subtitle: "Rewards are on the way. Check back soon."
        )
        .navigationTitle("Rewards")
    }
}
