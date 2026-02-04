import SwiftUI
import Supabase
import Auth
import Contacts

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            
            // --- Tab 1: Verify (核心功能：Tinder交互 + 相机定格) ---
            VerifyView()
                .tabItem {
                    Label("Verify", systemImage: "camera.viewfinder")
                }
                .tag(0)
            
            // --- Tab 2: Friend (排行榜 + 权限控制) ---
            FriendView()
                .tabItem {
                    Label("Friends", systemImage: "person.2.fill")
                }
                .tag(1)
            
            // --- Tab 3: Reward ---
            RewardView()
                .tabItem {
                    Label("Reward", systemImage: "gift.fill")
                }
                .tag(2)
            
            // --- Tab 4: Account ---
            AccountView()
                .tabItem {
                    Label("Account", systemImage: "person.circle.fill")
                }
                .tag(3)
        }
        .accentColor(.blue)
    }
}

// MARK: - 1. Verify View (核心重构)
struct VerifyView: View {
    @StateObject private var viewModel = TrashViewModel(classifier: RealClassifierService.shared)
    @StateObject private var cameraManager = CameraManager()
    
    // MARK: UI State
    // 控制滑动卡片的偏移量
    @State private var cardOffset: CGSize = .zero
    // 控制反馈表单的显示动画
    @State private var showingFeedbackForm = false
    
    // MARK: Form Data (反馈表单数据)
    @State private var selectedFeedbackCategory = "General Trash"
    @State private var feedbackItemName = ""
    let trashCategories = ["Recyclable", "Hazardous", "Compostable", "General Trash", "Electronic"]
    
    // MARK: - Computed Properties for UI Logic
    
    // 状态 A: 预览/闲置 (可以拍照)
    var isPreviewState: Bool {
        cameraManager.capturedImage == nil && viewModel.appState == .idle
    }
    
    // 状态 B: 显示结果卡片 (分析完成，且没有进入表单模式)
    var showResultCard: Bool {
        if case .finished = viewModel.appState, cameraManager.capturedImage != nil, !showingFeedbackForm {
            return true
        }
        return false
    }
    
    // 状态 C: 显示反馈表单 (用户右滑后)
    var showFeedbackForm: Bool {
        if case .collectingFeedback = viewModel.appState, showingFeedbackForm {
            return true
        }
        return false
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            
            VStack(spacing: 20) {
                // 顶部标题
                Text("The Trash")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 40)
                
                // --- 1. 相机/图片区域 ---
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.black)
                        .frame(height: 380)
                        .shadow(radius: 10)
                    
                    if let image = cameraManager.capturedImage {
                        // 显示定格照片
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 380)
                            .cornerRadius(24)
                            .clipped()
                            .overlay(
                                // 分析时的 Loading 遮罩
                                Group {
                                    if viewModel.appState == .analyzing {
                                        ZStack {
                                            Color.black.opacity(0.4)
                                            ProgressView("Analyzing...")
                                                .tint(.white)
                                                .foregroundColor(.white)
                                        }
                                    }
                                }
                            )
                    } else {
                        // 显示相机预览
                        CameraPreview(cameraManager: cameraManager)
                            .frame(height: 380)
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                            .overlay(
                                Group {
                                    if !cameraManager.permissionGranted {
                                        Text("Camera access needed").foregroundColor(.white)
                                    }
                                }
                            )
                    }
                }
                .padding(.horizontal)
                // 当表单出现时，稍微上移一点腾出空间
                .offset(y: showFeedbackForm ? -20 : 0)
                .animation(.spring(), value: showFeedbackForm)
                
                // --- 2. 动态内容区域 (高度固定，避免布局跳动) ---
                ZStack {
                    // 情况 A: 结果卡片 (可滑动)
                    if showResultCard, case .finished(let result) = viewModel.appState {
                        SwipeableResultCard(result: result, offset: $cardOffset) { direction in
                            handleSwipe(direction: direction, result: result)
                        }
                        // 覆盖在卡片上的提示字 (Like Tinder)
                        .overlay(
                            Text(cardOffset.width < 0 ? "✅ Accurate" : (cardOffset.width > 0 ? "❌ Inaccurate" : ""))
                                .font(.title2.bold())
                                .foregroundColor(cardOffset.width < 0 ? .green : .red)
                                .opacity(abs(cardOffset.width) > 50 ? 1 : 0) // 滑动一定距离才显示
                                .offset(y: -100)
                        )
                        // 卡片下方的滑动操作提示
                        .overlay(
                            VStack {
                                Spacer()
                                HStack {
                                    Image(systemName: "arrow.left")
                                    Text("Accurate")
                                    Spacer()
                                    Text("Inaccurate")
                                    Image(systemName: "arrow.right")
                                }
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding(.bottom, -30)
                            }
                        )
                        .transition(.scale.combined(with: .opacity))
                        .zIndex(2) // 确保在表单上层
                    }
                    
                    // 情况 B: 反馈表单
                    if showFeedbackForm {
                        FeedbackFormView(
                            selectedCategory: $selectedFeedbackCategory,
                            itemName: $feedbackItemName,
                            categories: trashCategories
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(1)
                    }
                }
                .frame(height: 150) // 固定高度区域
                
                Spacer()
                
                // --- 3. 底部大按钮 (动态变化) ---
                Button(action: handleMainButtonTap) {
                    HStack {
                        if showFeedbackForm {
                            Image(systemName: "paperplane.fill")
                            Text("Submit Feedback")
                        } else {
                            Image(systemName: "camera.shutter.button.fill")
                            Text("Identify Trash")
                        }
                    }
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    // 绿色=提交，蓝色=拍照
                    .background(showFeedbackForm ? Color.green : Color.blue)
                    .cornerRadius(16)
                    .shadow(radius: 5)
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
                // 只有在 "预览状态" 或 "填写表单状态" 按钮才可用
                // 在滑动卡片做决定时，按钮禁用
                .disabled(!isPreviewState && !showFeedbackForm)
                .opacity((!isPreviewState && !showFeedbackForm) ? 0.5 : 1.0)
            }
        }
        // 生命周期管理
        .onAppear {
            cameraManager.start()
            resetUIState()
        }
        .onDisappear { cameraManager.stop() }
        // 监听拍照 -> 分析
        .onReceive(cameraManager.$capturedImage) { img in
            if let img = img { viewModel.analyzeImage(image: img) }
        }
    }
    
    // MARK: - 逻辑处理函数
    
    // 1. 处理滑动
    private func handleSwipe(direction: SwipeDirection, result: TrashAnalysisResult) {
        if direction == .left {
            // 左滑：准确 ✅
            viewModel.handleCorrectFeedback()
            // 动画：卡片向左飞走
            withAnimation(.easeIn(duration: 0.3)) { cardOffset.width = -500 }
            
            // 延迟一点重置整个流程
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                finishFlowAndReset()
            }
        } else {
            // 右滑：不准确 ❌ -> 触发填表
            withAnimation(.easeIn(duration: 0.3)) { cardOffset.width = 500 } // 向右飞走
            
            // ViewModel 状态变更
            viewModel.prepareForIncorrectFeedback(wrongResult: result)
            
            // 延迟显示表单
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring()) {
                    self.showingFeedbackForm = true
                    self.cardOffset = .zero // 重置偏移量供下次使用
                }
            }
        }
    }
    
    // 2. 处理按钮点击
    private func handleMainButtonTap() {
        if showFeedbackForm {
            submitFeedback()
        } else if isPreviewState {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            cameraManager.takePhoto()
        }
    }
    
    // 3. 提交反馈
    private func submitFeedback() {
        guard case .collectingFeedback(let originalResult) = viewModel.appState else { return }
        
        Task {
            await viewModel.submitCorrection(
                originalResult: originalResult,
                correctedCategory: selectedFeedbackCategory,
                correctedName: feedbackItemName
            )
            // 提交完成后重置
            finishFlowAndReset()
        }
    }
    
    // 4. 重置流程 (回到拍照界面)
    private func finishFlowAndReset() {
        withAnimation {
            showingFeedbackForm = false
            cardOffset = .zero
            selectedFeedbackCategory = "General Trash"
            feedbackItemName = ""
        }
        // 重置业务逻辑和相机
        viewModel.reset()
        cameraManager.reset()
    }
    
    private func resetUIState() {
        showingFeedbackForm = false
        cardOffset = .zero
    }
}

// MARK: - 2. Friend View (排行榜 + 权限)
struct FriendView: View {
    @StateObject private var friendService = FriendService()
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Leaderboard")) {
                    if friendService.friends.isEmpty {
                        VStack(alignment: .center, spacing: 12) {
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
                        .frame(maxWidth: .infinity)
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
                
                // 只有未授权时显示按钮
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
                await friendService.findFriendsFromContacts()
            }
            .onAppear {
                friendService.checkAuthorizationStatus()
                if friendService.isAuthorized && friendService.friends.isEmpty {
                    Task { await friendService.findFriendsFromContacts() }
                }
            }
        }
    }
}

// MARK: - 3. Reward View
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

// MARK: - 4. Account View
struct AccountView: View {
    @EnvironmentObject var authVM: AuthViewModel
    
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

// MARK: - Supporting Views (组件)

enum SwipeDirection { case left, right }

// 1. 可滑动的卡片组件
struct SwipeableResultCard: View {
    let result: TrashAnalysisResult
    @Binding var offset: CGSize
    var onSwiped: (SwipeDirection) -> Void
    
    var body: some View {
        ResultCardContent(result: result)
            .offset(x: offset.width, y: 0)
            .rotationEffect(.degrees(Double(offset.width / 20)))
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        offset = gesture.translation
                    }
                    .onEnded { gesture in
                        if gesture.translation.width < -100 {
                            onSwiped(.left)
                        } else if gesture.translation.width > 100 {
                            onSwiped(.right)
                        } else {
                            withAnimation(.spring()) {
                                offset = .zero
                            }
                        }
                    }
            )
    }
}

// 2. 卡片视觉内容 (ResultCard)
struct ResultCardContent: View {
    let result: TrashAnalysisResult
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(result.category)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(result.color)
                Spacer()
                Text(String(format: "%.0f%% Confidence", result.confidence * 100))
                    .font(.caption).foregroundColor(.secondary)
            }
            Divider()
            HStack {
                Text("Detected:").fontWeight(.semibold)
                Text(result.itemName)
            }
            Text(result.actionTip)
                .font(.footnote)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        .padding(.horizontal)
    }
}

// 3. 反馈表单组件
struct FeedbackFormView: View {
    @Binding var selectedCategory: String
    @Binding var itemName: String
    let categories: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Help us improve!")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("What is this actually? (Required)")
                    .font(.caption).foregroundColor(.secondary)
                
                Picker("Category", selection: $selectedCategory) {
                    ForEach(categories, id: \.self) { cat in
                        Text(cat).tag(cat)
                    }
                }
                .pickerStyle(.menu)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Item Name (Optional)")
                    .font(.caption).foregroundColor(.secondary)
                TextField("e.g., Plastic Bottle Brand X", text: $itemName)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        .padding(.horizontal)
    }
}
