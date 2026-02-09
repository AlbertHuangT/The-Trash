//
//  AchievementsListView.swift
//  The Trash
//
//  Created by Albert Huang on 2/8/26.
//

import SwiftUI

struct AchievementsListView: View {
    @StateObject private var service = AchievementService.shared
    @State private var selectedTab = 0 // 0: Official, 1: Community
    
    var body: some View {
        VStack(spacing: 0) {
            Picker("Type", selection: $selectedTab) {
                Text("Official").tag(0)
                Text("Community").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()
            
            if service.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                List {
                    ForEach(filteredAchievements) { achievement in
                        AchievementRow(achievement: achievement) {
                            Task {
                                await service.equipAchievement(achievementId: achievement.achievementId)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Achievements")
        .onAppear {
            Task {
                await service.fetchMyAchievements()
            }
        }
    }
    
    var filteredAchievements: [UserAchievement] {
        if selectedTab == 0 {
            return service.myAchievements.filter { $0.isOfficial }
        } else {
            return service.myAchievements.filter { !$0.isOfficial }
        }
    }
}

struct AchievementRow: View {
    let achievement: UserAchievement
    let onEquip: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(achievement.isEquipped ? Color.purple.opacity(0.2) : Color.gray.opacity(0.1))
                    .frame(width: 50, height: 50)
                
                Image(systemName: achievement.iconName)
                    .font(.title2)
                    .foregroundColor(achievement.isEquipped ? .purple : .gray)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(achievement.name)
                    .font(.headline)
                    .foregroundColor(achievement.isEquipped ? .purple : .primary)
                
                if let desc = achievement.description {
                    Text(desc)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let communityName = achievement.communityName {
                    Text(communityName)
                        .font(.caption2)
                        .badgeStyle(foreground: .blue, background: Color.blue.opacity(0.1))
                }
            }
            
            Spacer()
            
            if achievement.isEquipped {
                Text("Equipped")
                    .font(.caption.bold())
                    .foregroundColor(.purple)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(8)
            } else {
                Button("Equip", action: onEquip)
                    .font(.caption.bold())
                    .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 4)
    }
}
