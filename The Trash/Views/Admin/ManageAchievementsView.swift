//
//  ManageAchievementsView.swift
//  The Trash
//
//  Created by Albert Huang on 2/8/26.
//

import SwiftUI
import Combine

struct ManageAchievementsView: View {
    let communityId: String
    @StateObject private var service = AchievementService.shared
    @State private var showingCreateSheet = false
    
    var body: some View {
        List {
            if service.communityAchievements.isEmpty {
                if service.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                } else {
                    Text("No achievements created yet.")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                }
            } else {
                ForEach(service.communityAchievements) { achievement in
                    HStack {
                        Image(systemName: achievement.iconName)
                            .font(.title2)
                            .foregroundColor(.purple)
                            .frame(width: 40)
                        
                        VStack(alignment: .leading) {
                            Text(achievement.name)
                                .font(.headline)
                            if let desc = achievement.description {
                                Text(desc)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Manage Achievements")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingCreateSheet = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingCreateSheet) {
            CreateAchievementView(communityId: communityId, isPresented: $showingCreateSheet)
        }
        .onAppear {
            Task {
                await service.fetchCommunityAchievements(communityId: communityId)
            }
        }
    }
}

private struct CreateAchievementView: View {
    let communityId: String
    @Binding var isPresented: Bool
    @StateObject private var service = AchievementService.shared
    
    @State private var name = ""
    @State private var description = ""
    @State private var selectedIcon = "star.fill"
    
    let icons = ["star.fill", "trophy.fill", "medal.fill", "rosette", "flame.fill", "bolt.fill", "leaf.fill", "drop.fill", "globe", "heart.fill"]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Details")) {
                    TextField("Achievement Name", text: $name)
                    TextField("Description", text: $description)
                }
                
                Section(header: Text("Icon")) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 40))], spacing: 10) {
                        ForEach(icons, id: \.self) { icon in
                            Image(systemName: icon)
                                .font(.title2)
                                .padding(8)
                                .background(selectedIcon == icon ? Color.purple.opacity(0.2) : Color.clear)
                                .cornerRadius(8)
                                .foregroundColor(selectedIcon == icon ? .purple : .primary)
                                .onTapGesture {
                                    selectedIcon = icon
                                }
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("New Achievement")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            let success = await service.createAchievement(
                                communityId: communityId,
                                name: name,
                                description: description,
                                iconName: selectedIcon
                            )
                            if success {
                                isPresented = false
                            }
                        }
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}
