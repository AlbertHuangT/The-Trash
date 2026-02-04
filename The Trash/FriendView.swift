//
//  FriendView.swift
//  The Trash
//
//  Created by Albert Huang on 2/4/26.
//


import SwiftUI

struct FriendView: View {
    @StateObject private var friendService = FriendService()
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                if friendService.friends.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "person.2.slash.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text("No friends yet").font(.title2).bold()
                        Button("Sync Contacts") {
                            Task { await friendService.findFriendsFromContacts() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    List(friendService.friends) { friend in
                        HStack {
                            Text("\(friend.rank)").bold().frame(width: 30)
                            Text(friend.username ?? "Anonymous")
                            Spacer()
                            Text("\(friend.credits) pts").foregroundColor(.blue)
                        }
                    }.listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Leaderboard")
        }
    }
}