import SwiftUI
import Supabase
import Auth
import Contacts

// MARK: - Enums (Re-added)
enum SwipeDirection {
    case left
    case right
}

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            
            // --- Tab 1: Verify ---
            VerifyView()
                .tabItem {
                    Label("Verify", systemImage: "camera.viewfinder")
                }
                .tag(0)
            
            // --- Tab 2: Friend ---
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

// MARK: - 1. Verify View (Fixed & Optimized)
struct VerifyView: View {
    @StateObject private var viewModel = TrashViewModel(classifier: RealClassifierService.shared)
    @StateObject private var cameraManager = CameraManager()
    
    // UI State
    @State private var cardOffset: CGSize = .zero
    @State private var showingFeedbackForm = false
    // 控制相机激活状态
    @State private var isCameraActive = false
    
    // Form Data
    @State private var selectedFeedbackCategory = "General Trash"
    @State private var feedbackItemName = ""
    let trashCategories = ["Recyclable", "Hazardous", "Compostable", "General Trash", "Electronic"]
    
    // Computed Properties
    var isPreviewState: Bool {
        cameraManager.capturedImage == nil && viewModel.appState == .idle
    }
    
    var showResultCard: Bool {
        if case .finished = viewModel.appState, cameraManager.capturedImage != nil, !showingFeedbackForm {
            return true
        }
        return false
    }
    
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
                // Header
                HStack {
                    Text("The Trash")
                        .font(.largeTitle)
                        .fontWeight(.heavy)
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 20)
                
                // --- 1. Camera/Image Area ---
                GeometryReader { geo in
                    ZStack {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color(.secondarySystemGroupedBackground))
                            .shadow(color: Color.black.opacity(0.15), radius: 15, x: 0, y: 5)
                        
                        if let image = cameraManager.capturedImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: geo.size.width, height: geo.size.height)
                                .cornerRadius(24)
                                .clipped()
                                .overlay(
                                    ZStack {
                                        if viewModel.appState == .analyzing {
                                            Color.black.opacity(0.5)
                                            VStack(spacing: 12) {
                                                ProgressView()
                                                    .tint(.white)
                                                    .scaleEffect(1.5)
                                                Text("Analyzing...")
                                                    .font(.headline)
                                                    .foregroundColor(.white)
                                            }
                                        }
                                    }
                                )
                        } else {
                            // 相机预览或待机占位
                            if isCameraActive {
                                CameraPreview(cameraManager: cameraManager)
                                    .frame(width: geo.size.width, height: geo.size.height)
                                    .clipShape(RoundedRectangle(cornerRadius: 24))
                                    .overlay(
                                        Group {
                                            if !cameraManager.permissionGranted {
                                                Text("Camera access needed")
                                                    .foregroundColor(.white)
                                                    .padding()
                                                    .background(Color.black.opacity(0.6))
                                                    .cornerRadius(10)
                                            }
                                        }
                                    )
                            } else {
                                // 待机状态：显示占位图
                                VStack(spacing: 16) {
                                    Image(systemName: "camera.aperture")
                                        .font(.system(size: 60))
                                        .foregroundColor(.secondary.opacity(0.5))
                                    Text("Tap button to scan trash")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                }
                                .frame(width: geo.size.width, height: geo.size.height)
                            }
                            
                            RoundedRectangle(cornerRadius: 24)
                                .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                        }
                    }
                }
                .frame(height: 400)
                .padding(.horizontal)
                .offset(y: showFeedbackForm ? -20 : 0)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showFeedbackForm)
                
                // --- 2. Dynamic Interaction Area ---
                ZStack {
                    if showResultCard, case .finished(let result) = viewModel.appState {
                        SwipeableResultCard(result: result, offset: $cardOffset) { direction in
                            handleSwipe(direction: direction, result: result)
                        }
                        .zIndex(2)
                        .transition(AnyTransition.asymmetric(
                            insertion: AnyTransition.scale.combined(with: AnyTransition.opacity),
                            removal: AnyTransition.opacity
                        ))
                    }
                    
                    if showFeedbackForm {
                        FeedbackFormView(
                            selectedCategory: $selectedFeedbackCategory,
                            itemName: $feedbackItemName,
                            categories: trashCategories
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(3)
                    }
                    
                    if isPreviewState && isCameraActive {
                        Text("Point at trash and snap")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 10)
                    }
                }
                .frame(height: 160)
                
                Spacer()
                
                // --- 3. Main Action Button ---
                Button(action: handleMainButtonTap) {
                    HStack {
                        if showFeedbackForm {
                            Image(systemName: "paperplane.fill")
                            Text("Submit")
                        } else if !isCameraActive {
                            // 相机未激活
                            Image(systemName: "camera.fill")
                            Text("Open Camera")
                        } else {
                            // 相机已激活，准备拍照
                            Image(systemName: "camera.shutter.button.fill")
                            Text("Identify")
                        }
                    }
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(
                            colors: showFeedbackForm ? [Color.green, Color.green.opacity(0.8)] : [Color.blue, Color.purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(28)
                    .shadow(color: (showFeedbackForm ? Color.green : Color.blue).opacity(0.4), radius: 10, x: 0, y: 5)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
                .disabled((!isPreviewState && !showFeedbackForm) && isCameraActive)
                .opacity(((!isPreviewState && !showFeedbackForm) && isCameraActive) ? 0.6 : 1.0)
                .scaleEffect(((!isPreviewState && !showFeedbackForm) && isCameraActive) ? 0.98 : 1.0)
                .animation(.easeInOut, value: isPreviewState)
            }
        }
        .onAppear {
            resetUIState()
        }
        .onDisappear {
            cameraManager.stop()
            isCameraActive = false
        }
        .onReceive(cameraManager.$capturedImage) { img in
            if let img = img { viewModel.analyzeImage(image: img) }
        }
    }
    
    // MARK: - Logic Handlers
    
    private func handleSwipe(direction: SwipeDirection, result: TrashAnalysisResult) {
        let generator = UINotificationFeedbackGenerator()
        
        // 🔥 修复逻辑：右滑 (Right) = 准确 (Accurate)，左滑 (Left) = 不准确 (Inaccurate)
        if direction == .right {
            // Right: Accurate -> Green
            generator.notificationOccurred(.success)
            viewModel.handleCorrectFeedback()
            withAnimation(.easeIn(duration: 0.3)) { cardOffset.width = 500 } // 向右飞出
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                finishFlowAndReset()
            }
        } else {
            // Left: Inaccurate -> Red
            generator.notificationOccurred(.warning)
            withAnimation(.easeIn(duration: 0.3)) { cardOffset.width = -500 } // 向左飞出
            
            viewModel.prepareForIncorrectFeedback(wrongResult: result)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring()) {
                    self.showingFeedbackForm = true
                    self.cardOffset = .zero
                }
            }
        }
    }
    
    private func handleMainButtonTap() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        if showFeedbackForm {
            submitFeedback()
        } else if !isCameraActive {
            withAnimation { isCameraActive = true }
            cameraManager.start()
        } else if isPreviewState {
            cameraManager.takePhoto()
        }
    }
    
    private func submitFeedback() {
        guard case .collectingFeedback(let originalResult) = viewModel.appState else { return }
        guard let currentImage = cameraManager.capturedImage else { return }
        
        Task {
            await viewModel.submitCorrection(
                image: currentImage,
                originalResult: originalResult,
                correctedCategory: selectedFeedbackCategory,
                correctedName: feedbackItemName
            )
            finishFlowAndReset()
        }
    }
    
    private func finishFlowAndReset() {
        withAnimation {
            showingFeedbackForm = false
            cardOffset = .zero
            selectedFeedbackCategory = "General Trash"
            feedbackItemName = ""
        }
        viewModel.reset()
        cameraManager.reset()
    }
    
    private func resetUIState() {
        showingFeedbackForm = false
        cardOffset = .zero
    }
}

// MARK: - 2. Friend View (Unchanged)
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
                        Text("No friends yet")
                            .font(.title2)
                            .bold()
                            .foregroundColor(.primary)
                        
                        if !friendService.isAuthorized {
                            Text("Sync contacts to compete!")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            Button(action: {
                                Task { await friendService.findFriendsFromContacts() }
                            }) {
                                Text("Sync Contacts")
                                    .fontWeight(.bold)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal, 40)
                        } else {
                            Text("None of your contacts are playing yet.\nInvite them!")
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    List {
                        ForEach(friendService.friends) { friend in
                            HStack(spacing: 16) {
                                ZStack {
                                    if friend.rank <= 3 {
                                        Circle()
                                            .fill(rankColor(for: friend.rank).opacity(0.2))
                                            .frame(width: 36, height: 36)
                                        Image(systemName: "crown.fill")
                                            .foregroundColor(rankColor(for: friend.rank))
                                    } else {
                                        Text("\(friend.rank)")
                                            .font(.headline)
                                            .foregroundColor(.secondary)
                                            .frame(width: 36)
                                    }
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(friend.username ?? "User \(friend.rank)")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text("Eco Warrior")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Text("\(friend.credits)")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                                Text("pts")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 8)
                            .listRowBackground(Color(.secondarySystemGroupedBackground))
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Leaderboard")
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
    
    func rankColor(for rank: Int) -> Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .primary
        }
    }
}

// MARK: - 3. Reward View
struct RewardView: View {
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                VStack(spacing: 24) {
                    Image(systemName: "gift.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .foregroundStyle(.orange.gradient)
                        .shadow(radius: 10)
                    
                    VStack(spacing: 8) {
                        Text("Rewards Center")
                            .font(.title2)
                            .bold()
                            .foregroundColor(.primary)
                        
                        Text("Use credits to redeem eco-gifts!")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    Button("Coming Soon") { }
                        .buttonStyle(.borderedProminent)
                        .tint(.gray)
                        .disabled(true)
                }
                .padding()
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
                Section {
                    HStack(spacing: 16) {
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 60, height: 60)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.title)
                                    .foregroundColor(.blue)
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            if let email = authVM.session?.user.email {
                                Text(email).font(.headline)
                            } else if let phone = authVM.session?.user.phone {
                                Text(phone).font(.headline)
                            } else {
                                Text("Guest").font(.headline)
                            }
                            Text("Member")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.15))
                                .cornerRadius(4)
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Profile")
                }
                .listRowBackground(Color(.secondarySystemGroupedBackground))
                
                Section {
                    HStack {
                        Label("Email", systemImage: "envelope.fill")
                            .foregroundColor(.primary)
                        Spacer()
                        if let email = authVM.session?.user.email, !email.isEmpty {
                            Text("Linked")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                                .padding(6)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(6)
                        } else {
                            Button("Link") { showBindEmailSheet = true }
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    HStack {
                        Label("Phone", systemImage: "phone.fill")
                            .foregroundColor(.primary)
                        Spacer()
                        if let phone = authVM.session?.user.phone, !phone.isEmpty {
                            Text("Linked")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                                .padding(6)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(6)
                        } else {
                            Button("Link") { showBindPhoneSheet = true }
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                    }
                } header: {
                    Text("Account Binding")
                }
                .listRowBackground(Color(.secondarySystemGroupedBackground))
                
                Section {
                    Button(action: {
                        Task { await authVM.signOut() }
                    }) {
                        Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(.red)
                    }
                }
                .listRowBackground(Color(.secondarySystemGroupedBackground))
            }
            .listStyle(.insetGrouped)
            .navigationTitle("My Account")
            .sheet(isPresented: $showBindPhoneSheet) {
                BindPhoneSheet(inputPhone: $inputPhone, inputOTP: $inputOTP, authVM: authVM, isPresented: $showBindPhoneSheet)
            }
            .sheet(isPresented: $showBindEmailSheet) {
                BindEmailSheet(inputEmail: $inputEmail, authVM: authVM, isPresented: $showBindEmailSheet)
            }
        }
    }
}

// Helper Sheets
struct BindPhoneSheet: View {
    @Binding var inputPhone: String
    @Binding var inputOTP: String
    @ObservedObject var authVM: AuthViewModel
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            Form {
                if !authVM.showOTPInput {
                    Section(header: Text("Enter Phone")) {
                        TextField("Phone (+1...)", text: $inputPhone)
                            .keyboardType(.phonePad)
                        Button("Send Code") {
                            Task { await authVM.bindPhone(phone: inputPhone) }
                        }
                    }
                } else {
                    Section(header: Text("Enter OTP")) {
                        TextField("Code", text: $inputOTP)
                            .keyboardType(.numberPad)
                        Button("Verify & Link") {
                            Task {
                                await authVM.confirmBindPhone(phone: inputPhone, token: inputOTP)
                                isPresented = false
                                authVM.showOTPInput = false
                            }
                        }
                    }
                }
            }
            .navigationTitle("Bind Phone")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { isPresented = false } } }
        }
    }
}

struct BindEmailSheet: View {
    @Binding var inputEmail: String
    @ObservedObject var authVM: AuthViewModel
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Enter Email")) {
                    TextField("Email", text: $inputEmail)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    Button("Send Confirmation") {
                        Task {
                            await authVM.bindEmail(email: inputEmail)
                            isPresented = false
                        }
                    }
                }
            }
            .navigationTitle("Bind Email")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { isPresented = false } } }
        }
    }
}


// MARK: - Components (Fixed)

struct SwipeableResultCard: View {
    let result: TrashAnalysisResult
    @Binding var offset: CGSize
    var onSwiped: (SwipeDirection) -> Void
    
    var body: some View {
        ZStack {
            ResultCardContent(result: result)
            
            // Swipe Overlay
            if offset.width > 20 {
                // 🔥 修复：右滑 (Right) 显示绿色 Checkmark (Accurate)
                // 图标显示在左侧，跟随卡片向右移动
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.green)
                        .padding()
                    Spacer()
                }
                .opacity(min(abs(offset.width)/150.0, 1.0))
            } else if offset.width < -20 {
                // 🔥 修复：左滑 (Left) 显示红色 Xmark (Inaccurate)
                // 图标显示在右侧，跟随卡片向左移动
                HStack {
                    Spacer()
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.red)
                        .padding()
                }
                .opacity(min(abs(offset.width)/150.0, 1.0))
            }
        }
        .offset(x: offset.width)
        .rotationEffect(.degrees(Double(offset.width / 15)))
        .gesture(
            DragGesture()
                .onChanged { gesture in
                    offset = gesture.translation
                }
                .onEnded { gesture in
                    if gesture.translation.width < -100 {
                        onSwiped(.left) // 触发左滑
                    } else if gesture.translation.width > 100 {
                        onSwiped(.right) // 触发右滑
                    } else {
                        withAnimation(.spring()) {
                            offset = .zero
                        }
                    }
                }
        )
    }
}

struct ResultCardContent: View {
    let result: TrashAnalysisResult
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text(result.category)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(result.color)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.caption)
                    Text("\(Int(result.confidence * 100))%")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.tertiarySystemGroupedBackground))
                .cornerRadius(8)
            }
            
            Divider()
            
            // Content
            VStack(alignment: .leading, spacing: 6) {
                Text("Detected:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                Text(result.itemName)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            
            // Tips
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text(result.actionTip)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .background(Color(.tertiarySystemGroupedBackground))
            .cornerRadius(12)
            
            // Bottom hints
            // 🔥 修复：底部提示文字对调，左=不准，右=准
            HStack {
                Image(systemName: "arrow.left")
                Text("Accurate") // 左边：不准确
                Spacer()
                Text("Inaccurate")   // 右边：准确
                Image(systemName: "arrow.right")
            }
            .font(.caption)
            .foregroundColor(Color(uiColor: .tertiaryLabel))
            .padding(.top, 4)
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        .padding(.horizontal)
    }
}

struct FeedbackFormView: View {
    @Binding var selectedCategory: String
    @Binding var itemName: String
    let categories: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Correction")
                    .font(.headline)
                Spacer()
                Image(systemName: "square.and.pencil")
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Correct Category (Required)")
                    .font(.caption).foregroundColor(.secondary)
                
                Menu {
                    ForEach(categories, id: \.self) { cat in
                        Button(action: { selectedCategory = cat }) {
                            Text(cat)
                            if selectedCategory == cat { Image(systemName: "checkmark") }
                        }
                    }
                } label: {
                    HStack {
                        Text(selectedCategory)
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.tertiarySystemGroupedBackground))
                    .cornerRadius(10)
                }
            }
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Item Name (Optional)")
                    .font(.caption).foregroundColor(.secondary)
                TextField("e.g. Starbucks Cup", text: $itemName)
                    .padding()
                    .background(Color(.tertiarySystemGroupedBackground))
                    .cornerRadius(10)
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        .padding(.horizontal)
    }
}
