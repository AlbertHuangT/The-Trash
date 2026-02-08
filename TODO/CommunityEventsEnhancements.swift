//
//  CommunityEventsEnhancements.swift
//  优化建议示例代码
//
//  这个文件包含了对Community和Events功能的优化建议
//

import SwiftUI
import MapKit

// MARK: - 1. 增强的活动卡片（带图片）

struct EnhancedEventCard: View {
    let event: CommunityEvent
    let registeredFriends: [String] // 已报名的朋友
    @State private var imageURL: URL?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 顶部封面图
            eventCoverImage
                .frame(height: 180)
                .clipped()
            
            // 内容区域
            VStack(alignment: .leading, spacing: 12) {
                // 标题和类别
                HStack {
                    Text(event.category.rawValue)
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(event.category.color)
                        .cornerRadius(8)
                    
                    Spacer()
                    
                    // 快满了提示
                    if event.participantCount >= event.maxParticipants * 0.8 {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.circle.fill")
                            Text("快满了")
                        }
                        .font(.caption.bold())
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(8)
                    }
                }
                
                Text(event.title)
                    .font(.title3.bold())
                    .lineLimit(2)
                
                // 时间和地点
                VStack(alignment: .leading, spacing: 6) {
                    Label(event.date.formatted(), systemImage: "calendar")
                    Label(event.location, systemImage: "mappin.circle.fill")
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
                
                // 已报名的朋友
                if !registeredFriends.isEmpty {
                    HStack(spacing: -8) {
                        ForEach(registeredFriends.prefix(3), id: \.self) { friend in
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Text(String(friend.prefix(1)))
                                        .font(.caption.bold())
                                        .foregroundColor(.white)
                                )
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 2)
                                )
                        }
                        
                        if registeredFriends.count > 3 {
                            Text("+\(registeredFriends.count - 3)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 4)
                        }
                        
                        Text("个朋友已报名")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 4)
                    }
                }
                
                // 底部状态栏
                HStack {
                    Label("\(event.participantCount)/\(event.maxParticipants)", 
                          systemImage: "person.2.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if event.isRegistered {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("已报名")
                        }
                        .font(.caption.bold())
                        .foregroundColor(.green)
                    }
                }
            }
            .padding(16)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
    }
    
    private var eventCoverImage: some View {
        Group {
            if let url = imageURL {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    gradientPlaceholder
                }
            } else {
                gradientPlaceholder
            }
        }
    }
    
    private var gradientPlaceholder: some View {
        LinearGradient(
            colors: [event.category.color.opacity(0.8), event.category.color],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Image(systemName: event.imageSystemName)
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.5))
        )
    }
}

// MARK: - 2. 社区动态墙

struct CommunityFeedView: View {
    let communityId: String
    @State private var posts: [CommunityPost] = []
    @State private var showCreatePost = false
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // 创建动态按钮
                createPostButton
                
                // 动态列表
                ForEach(posts) { post in
                    CommunityPostCard(post: post)
                }
            }
            .padding()
        }
        .navigationTitle("社区动态")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showCreatePost = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
            }
        }
        .sheet(isPresented: $showCreatePost) {
            CreatePostView(communityId: communityId)
        }
    }
    
    private var createPostButton: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.blue)
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "person.fill")
                        .foregroundColor(.white)
                )
            
            Text("分享你的环保成果...")
                .foregroundColor(.secondary)
            
            Spacer()
            
            Image(systemName: "photo")
                .foregroundColor(.blue)
        }
        .padding()
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(12)
        .onTapGesture {
            showCreatePost = true
        }
    }
}

struct CommunityPost: Identifiable {
    let id: UUID
    let authorName: String
    let authorAvatar: String?
    let content: String
    let images: [URL]
    let likeCount: Int
    let commentCount: Int
    let createdAt: Date
    var isLiked: Bool
}

struct CommunityPostCard: View {
    let post: CommunityPost
    @State private var isLiked: Bool
    
    init(post: CommunityPost) {
        self.post = post
        _isLiked = State(initialValue: post.isLiked)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 作者信息
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(String(post.authorName.prefix(1)))
                            .font(.headline)
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(post.authorName)
                        .font(.headline)
                    Text(timeAgo(from: post.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.secondary)
                }
            }
            
            // 内容
            Text(post.content)
                .font(.body)
            
            // 图片网格
            if !post.images.isEmpty {
                imageGrid
            }
            
            // 互动栏
            HStack(spacing: 24) {
                Button(action: { isLiked.toggle() }) {
                    HStack(spacing: 4) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .foregroundColor(isLiked ? .red : .secondary)
                        Text("\(post.likeCount + (isLiked ? 1 : 0))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Button(action: {}) {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.right")
                            .foregroundColor(.secondary)
                        Text("\(post.commentCount)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    private var imageGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 8) {
            ForEach(post.images.prefix(4), id: \.self) { url in
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                }
                .frame(height: 150)
                .clipped()
                .cornerRadius(8)
            }
        }
    }
    
    private func timeAgo(from date: Date) -> String {
        let seconds = Date().timeIntervalSince(date)
        if seconds < 60 { return "刚刚" }
        if seconds < 3600 { return "\(Int(seconds / 60))分钟前" }
        if seconds < 86400 { return "\(Int(seconds / 3600))小时前" }
        return "\(Int(seconds / 86400))天前"
    }
}

// MARK: - 3. 活动地图视图

struct EventsMapView: View {
    let events: [CommunityEvent]
    @State private var region: MKCoordinateRegion
    @State private var selectedEvent: CommunityEvent?
    
    init(events: [CommunityEvent], userLocation: CLLocationCoordinate2D?) {
        self.events = events
        
        if let location = userLocation {
            _region = State(initialValue: MKCoordinateRegion(
                center: location,
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            ))
        } else if let firstEvent = events.first {
            _region = State(initialValue: MKCoordinateRegion(
                center: CLLocationCoordinate2D(
                    latitude: firstEvent.latitude,
                    longitude: firstEvent.longitude
                ),
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            ))
        } else {
            _region = State(initialValue: MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            ))
        }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Map(coordinateRegion: $region, annotationItems: events) { event in
                MapAnnotation(coordinate: CLLocationCoordinate2D(
                    latitude: event.latitude,
                    longitude: event.longitude
                )) {
                    eventMarker(event)
                }
            }
            .edgesIgnoringSafeArea(.all)
            
            // 底部卡片预览
            if let event = selectedEvent {
                EventPreviewCard(event: event) {
                    selectedEvent = nil
                }
                .transition(.move(edge: .bottom))
                .padding()
            }
        }
    }
    
    private func eventMarker(_ event: CommunityEvent) -> some View {
        ZStack {
            Circle()
                .fill(event.category.color)
                .frame(width: 40, height: 40)
                .shadow(radius: 3)
            
            Image(systemName: event.imageSystemName)
                .foregroundColor(.white)
                .font(.system(size: 18))
        }
        .onTapGesture {
            selectedEvent = event
        }
    }
}

struct EventPreviewCard: View {
    let event: CommunityEvent
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // 类别图标
            ZStack {
                Circle()
                    .fill(event.category.color.opacity(0.15))
                    .frame(width: 50, height: 50)
                Image(systemName: event.imageSystemName)
                    .foregroundColor(event.category.color)
            }
            
            // 信息
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.headline)
                    .lineLimit(1)
                
                Label(event.location, systemImage: "mappin.circle.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Label("\(event.participantCount)/\(event.maxParticipants)", 
                      systemImage: "person.2.fill")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            
            Spacer()
            
            // 箭头
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(radius: 10)
        )
    }
}

// MARK: - 4. 活动签到功能

struct EventCheckInView: View {
    let event: CommunityEvent
    @State private var isCheckingIn = false
    @State private var checkInSuccess = false
    @State private var uploadedImages: [UIImage] = []
    @State private var showImagePicker = false
    
    var body: some View {
        VStack(spacing: 24) {
            // 活动信息
            eventInfo
            
            Divider()
            
            // 上传活动照片
            photoUploadSection
            
            Spacer()
            
            // 签到按钮
            checkInButton
        }
        .padding()
        .navigationTitle("活动签到")
        .alert("签到成功!", isPresented: $checkInSuccess) {
            Button("确定", role: .cancel) {}
        } message: {
            Text("你已成功签到，积分已添加到你的账户！")
        }
    }
    
    private var eventInfo: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(event.title)
                .font(.title2.bold())
            
            Label(event.location, systemImage: "mappin.circle.fill")
                .foregroundColor(.secondary)
            
            Label(event.date.formatted(), systemImage: "calendar")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var photoUploadSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("分享活动照片")
                .font(.headline)
            
            Text("拍摄活动现场照片，记录美好时刻")
                .font(.caption)
                .foregroundColor(.secondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // 添加照片按钮
                    Button(action: { showImagePicker = true }) {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue, style: StrokeStyle(lineWidth: 2, dash: [5]))
                            .frame(width: 100, height: 100)
                            .overlay(
                                VStack {
                                    Image(systemName: "camera.fill")
                                        .font(.title2)
                                    Text("添加照片")
                                        .font(.caption)
                                }
                                .foregroundColor(.blue)
                            )
                    }
                    
                    // 已上传的照片
                    ForEach(uploadedImages.indices, id: \.self) { index in
                        Image(uiImage: uploadedImages[index])
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .cornerRadius(12)
                            .overlay(
                                Button(action: {
                                    uploadedImages.remove(at: index)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.white)
                                        .background(Circle().fill(Color.black.opacity(0.5)))
                                }
                                .padding(4),
                                alignment: .topTrailing
                            )
                    }
                }
            }
        }
    }
    
    private var checkInButton: some View {
        Button(action: performCheckIn) {
            HStack {
                if isCheckingIn {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                    Text("确认签到")
                }
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [Color.green, Color.green.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
        }
        .disabled(isCheckingIn)
    }
    
    private func performCheckIn() {
        isCheckingIn = true
        
        // 模拟签到API调用
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isCheckingIn = false
            checkInSuccess = true
        }
    }
}

// MARK: - 5. 社区成就系统

struct CommunityAchievementsView: View {
    let communityId: String
    @State private var achievements: [CommunityAchievement] = sampleAchievements
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 总体进度
                communityProgressCard
                
                // 当前挑战
                currentChallengesSection
                
                // 徽章墙
                badgesSection
            }
            .padding()
        }
        .navigationTitle("社区成就")
    }
    
    private var communityProgressCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("社区总积分")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("12,450")
                        .font(.system(size: 36, weight: .bold))
                }
                
                Spacer()
                
                Image(systemName: "trophy.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.yellow)
            }
            
            // 排名
            HStack {
                Label("城市排名", systemImage: "chart.bar.fill")
                Spacer()
                Text("#3")
                    .font(.headline)
                    .foregroundColor(.blue)
            }
            .padding()
            .background(Color(.tertiarySystemGroupedBackground))
            .cornerRadius(12)
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
    }
    
    private var currentChallengesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("本月挑战")
                .font(.headline)
            
            ForEach(achievements.filter { !$0.isCompleted }) { achievement in
                ChallengeCard(achievement: achievement)
            }
        }
    }
    
    private var badgesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("社区徽章")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(achievements) { achievement in
                    BadgeView(achievement: achievement)
                }
            }
        }
    }
}

struct CommunityAchievement: Identifiable {
    let id: UUID
    let title: String
    let description: String
    let icon: String
    let progress: Double
    let target: Int
    let isCompleted: Bool
    let color: Color
}

let sampleAchievements = [
    CommunityAchievement(
        id: UUID(),
        title: "回收达人",
        description: "本月回收1000kg垃圾",
        icon: "arrow.3.trianglepath",
        progress: 0.75,
        target: 1000,
        isCompleted: false,
        color: .green
    ),
    CommunityAchievement(
        id: UUID(),
        title: "活动组织者",
        description: "组织10场活动",
        icon: "calendar.badge.plus",
        progress: 1.0,
        target: 10,
        isCompleted: true,
        color: .blue
    ),
    CommunityAchievement(
        id: UUID(),
        title: "百人社区",
        description: "社区成员达到100人",
        icon: "person.3.fill",
        progress: 0.92,
        target: 100,
        isCompleted: false,
        color: .purple
    )
]

struct ChallengeCard: View {
    let achievement: CommunityAchievement
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: achievement.icon)
                    .font(.title2)
                    .foregroundColor(achievement.color)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(achievement.title)
                        .font(.headline)
                    Text(achievement.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text("\(Int(achievement.progress * 100))%")
                    .font(.headline)
                    .foregroundColor(achievement.color)
            }
            
            ProgressView(value: achievement.progress)
                .tint(achievement.color)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

struct BadgeView: View {
    let achievement: CommunityAchievement
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(achievement.isCompleted ? achievement.color.opacity(0.2) : Color.gray.opacity(0.1))
                    .frame(width: 70, height: 70)
                
                Image(systemName: achievement.icon)
                    .font(.title)
                    .foregroundColor(achievement.isCompleted ? achievement.color : .gray)
            }
            
            Text(achievement.title)
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundColor(achievement.isCompleted ? .primary : .secondary)
        }
        .opacity(achievement.isCompleted ? 1 : 0.5)
    }
}

// MARK: - 创建动态视图占位

struct CreatePostView: View {
    let communityId: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Text("创建动态")
                .navigationTitle("新动态")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("发布") { dismiss() }
                    }
                }
        }
    }
}
