import SwiftUI
import Supabase
import Auth
import Contacts // 需要引入 Contacts 框架（虽然逻辑在 Service 里，但 View 可能需要相关类型）

struct ContentView: View {
    // 选中的 Tab 索引
    @State private var selectedTab = 0
    
    var body: some View {
        // 使用 TabView 实现底部导航栏
        TabView(selection: $selectedTab) {
            
            // --- Tab 1: Verify (核心功能 + 游戏化动画) ---
            VerifyView()
                .tabItem {
                    Label("Verify", systemImage: "camera.viewfinder")
                }
                .tag(0)
            
            // --- Tab 2: Friend (排行榜) ---
            FriendView()
                .tabItem {
                    Label("Friends", systemImage: "person.2.fill")
                }
                .tag(1)
            
            // --- Tab 3: Reward (奖励) ---
            RewardView()
                .tabItem {
                    Label("Reward", systemImage: "gift.fill")
                }
                .tag(2)
            
            // --- Tab 4: My Account (个人中心) ---
            AccountView()
                .tabItem {
                    Label("Account", systemImage: "person.circle.fill")
                }
                .tag(3)
        }
        // 设置 Tab 选中时的颜色
        .accentColor(.blue)
    }
}

// MARK: - 1. Verify View (核心 + 积分动画)
struct VerifyView: View {
    @StateObject private var viewModel = TrashViewModel(classifier: RealClassifierService.shared)
    @EnvironmentObject var authVM: AuthViewModel
    
    @State private var showCamera = false
    @State private var capturedImage: UIImage?
    @State private var showReportSheet = false
    
    // 🔥 游戏化动画状态
    @State private var showPointsAnimation = false
    @State private var pointsOpacity = 0.0
    @State private var pointsOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            
            VStack(spacing: 30) {
                // 顶部标题
                Text("The Trash")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 40)
                
                // --- 取景/图片区域 ---
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color(.tertiarySystemFill))
                        .frame(height: 350)
                        .shadow(radius: 10)
                    
                    if viewModel.appState == .analyzing {
                        ProgressView()
                            .scaleEffect(1.5)
                    } else if let image = capturedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 350)
                            .cornerRadius(24)
                            .clipped()
                    } else {
                        VStack {
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary)
                            Text("Tap Camera to Scan")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal)
                .onTapGesture {
                    showCamera = true
                }
                
                // --- 结果卡片 ---
                if case .finished(let result) = viewModel.appState {
                    ResultCard(result: result, onReport: {
                        self.showReportSheet = true
                    })
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                Spacer()
                
                // --- 底部大按钮 ---
                Button(action: {
                    showCamera = true
                }) {
                    HStack {
                        Image(systemName: "camera.fill")
                        Text("Identify Trash")
                    }
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(16)
                    .shadow(radius: 5)
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
            
            // --- 🔥 游戏化：积分弹窗动画层 ---
            if showPointsAnimation {
                VStack {
                    Text("+ 20 Credits!")
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                        .foregroundColor(.yellow)
                        .shadow(color: .orange, radius: 2, x: 1, y: 1)
                        .padding()
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.7))
                                .shadow(radius: 10)
                        )
                        .scaleEffect(showPointsAnimation ? 1.1 : 0.5)
                }
                .offset(y: pointsOffset)
                .opacity(pointsOpacity)
                .zIndex(100) // 确保在最上层
                .onAppear {
                    // 动画逻辑：向上飘动并消失
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                        pointsOffset = -100 // 向上飘
                        pointsOpacity = 1.0
                    }
                    
                    // 1.5秒后消失
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation(.easeOut) {
                            pointsOpacity = 0.0
                            pointsOffset = -200
                        }
                        // 重置状态
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            showPointsAnimation = false
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraView(selectedImage: $capturedImage)
        }
        // 监听图片变化，开始分析
        .onChange(of: capturedImage) { newImage in
            if let img = newImage {
                viewModel.analyzeImage(image: img)
            }
        }
        // 🔥 监听状态变化，触发动画
        .onChange(of: viewModel.appState) { newState in
            if case .finished(let result) = newState {
                // 只有识别成功才弹动画
                if result.confidence > 0.4 {
                    // 重置初始位置并触发
                    pointsOffset = 0
                    pointsOpacity = 0
                    showPointsAnimation = true
                }
            }
        }
        .sheet(isPresented: $showReportSheet) {
            if case .finished(let result) = viewModel.appState,
               let image = capturedImage {
                ReportView(
                    predictedResult: result,
                    image: image,
                    userId: authVM.session?.user.id
                )
            }
        }
        .animation(.spring(), value: viewModel.appState)
    }
}

// MARK: - 2. Friend View (排行榜)
struct FriendView: View {
    @StateObject private var friendService = FriendService()
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Leaderboard")) {
                    if friendService.friends.isEmpty {
                        VStack(alignment: .center, spacing: 12) {
                            // ✨ 根据权限状态切换提示文案
                            if friendService.isAuthorized {
                                Text("No friends found yet.")
                                    .foregroundColor(.secondary)
                                Text("None of your contacts are playing yet.\nInvite them to join!")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                            } else {
                                Text("Waiting to sync...")
                                    .foregroundColor(.secondary)
                                Text("Sync contacts to compete with friends!")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.vertical)
                        .frame(maxWidth: .infinity) // 居中对齐
                    } else {
                        ForEach(friendService.friends) { friend in
                            HStack {
                                if friend.rank <= 3 {
                                    Image(systemName: "crown.fill")
                                        .foregroundColor(friend.rank == 1 ? .yellow : (friend.rank == 2 ? .gray : .orange))
                                } else {
                                    Text("\(friend.rank)")
                                        .font(.headline)
                                        .frame(width: 25)
                                        .foregroundColor(.secondary)
                                }
                                
                                VStack(alignment: .leading) {
                                    Text(friend.username ?? "User \(friend.rank)")
                                        .fontWeight(.semibold)
                                }
                                
                                Spacer()
                                
                                Text("\(friend.credits) pts")
                                    .bold()
                                    .foregroundColor(.blue)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                
                // ✨ 只有在未获得权限时，才显示“Find Friends”按钮
                if !friendService.isAuthorized {
                    Section {
                        Button(action: {
                            Task { await friendService.findFriendsFromContacts() }
                        }) {
                            Label("Find Friends from Contacts", systemImage: "person.crop.circle.badge.plus")
                        }
                        if friendService.permissionError {
                            Text("Please enable Contacts access in Settings.")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle("Friends & Rankings")
            .refreshable {
                // 下拉刷新时，如果已有权限，直接刷新列表
                await friendService.findFriendsFromContacts()
            }
            .onAppear {
                // 每次进入页面检查一下权限状态（防止用户在设置里改了）
                friendService.checkAuthorizationStatus()
                // 自动尝试加载（可选）
                if friendService.isAuthorized && friendService.friends.isEmpty {
                    Task { await friendService.findFriendsFromContacts() }
                }
            }
        }
    }
}
// MARK: - 3. Reward View (保持占位，等待未来开发兑换功能)
struct RewardView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "gift.circle")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.orange)
                
                Text("Rewards Center")
                    .font(.title2)
                    .bold()
                
                Text("Use your credits to redeem eco-friendly gifts!")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button("Coming Soon") { }
                    .buttonStyle(.bordered)
                    .disabled(true)
            }
            .navigationTitle("Rewards")
        }
    }
}

// MARK: - 4. Account View (保持原有的绑定逻辑)
struct AccountView: View {
    @EnvironmentObject var authVM: AuthViewModel
    
    // 绑定弹窗状态
    @State private var showBindPhoneSheet = false
    @State private var showBindEmailSheet = false
    @State private var inputPhone = "+1"
    @State private var inputEmail = ""
    @State private var inputOTP = ""
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Profile")) {
                    HStack {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            if let email = authVM.session?.user.email {
                                Text(email).font(.headline)
                            } else if let phone = authVM.session?.user.phone {
                                Text(phone).font(.headline)
                            } else {
                                Text("User").font(.headline)
                            }
                            Text("The Trash Member")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section(header: Text("Linked Accounts")) {
                    // Email Link
                    if let email = authVM.session?.user.email, !email.isEmpty {
                        HStack {
                            Label("Email", systemImage: "envelope.fill")
                            Spacer()
                            Text("Linked").foregroundColor(.secondary).font(.caption)
                        }
                    } else {
                        Button(action: { showBindEmailSheet = true }) {
                            HStack {
                                Label("Link Email", systemImage: "envelope")
                                Spacer()
                                Image(systemName: "plus.circle")
                            }
                        }
                    }
                    
                    // Phone Link
                    if let phone = authVM.session?.user.phone, !phone.isEmpty {
                        HStack {
                            Label("Phone", systemImage: "phone.fill")
                            Spacer()
                            Text("Linked").foregroundColor(.secondary).font(.caption)
                        }
                    } else {
                        Button(action: { showBindPhoneSheet = true }) {
                            HStack {
                                Label("Link Phone", systemImage: "phone")
                                Spacer()
                                Image(systemName: "plus.circle")
                            }
                        }
                    }
                }
                
                Section {
                    Button(action: {
                        Task { await authVM.signOut() }
                    }) {
                        Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("My Account")
            // --- Sheets ---
            .sheet(isPresented: $showBindPhoneSheet) {
                VStack(spacing: 20) {
                    Text("Link Phone Number").font(.headline)
                    if !authVM.showOTPInput {
                        TextField("Phone (+1...)", text: $inputPhone)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.phonePad)
                        Button("Send Code") {
                            Task { await authVM.bindPhone(phone: inputPhone) }
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        TextField("Code", text: $inputOTP)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numberPad)
                        Button("Verify & Link") {
                            Task {
                                await authVM.confirmBindPhone(phone: inputPhone, token: inputOTP)
                                showBindPhoneSheet = false
                                authVM.showOTPInput = false
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showBindEmailSheet) {
                VStack(spacing: 20) {
                    Text("Link Email Address").font(.headline)
                    TextField("Email", text: $inputEmail)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.emailAddress)
                    Button("Send Confirmation") {
                        Task {
                            await authVM.bindEmail(email: inputEmail)
                            showBindEmailSheet = false
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    Text("You will need to click the link in your email to finish linking.")
                        .font(.caption).foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .presentationDetents([.medium])
            }
        }
    }
}

// MARK: - Result Card (UI 组件)
struct ResultCard: View {
    let result: TrashAnalysisResult
    var onReport: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(result.category)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(result.color)
                Spacer()
                Text(String(format: "Confidence: %.0f%%", result.confidence * 100))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Divider()
            HStack {
                Text("Item:")
                    .fontWeight(.semibold)
                Text(result.itemName)
            }
            HStack(alignment: .top) {
                Text("Tip:")
                    .fontWeight(.semibold)
                Text(result.actionTip)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Divider()
            
            Button(action: onReport) {
                HStack {
                    Image(systemName: "exclamationmark.bubble.fill")
                    Text("Report Incorrect Result")
                }
                .font(.footnote)
                .foregroundColor(.red.opacity(0.8))
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }
}
