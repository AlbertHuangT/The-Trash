import SwiftUI
import Supabase
import Auth

struct ContentView: View {
    // 选中的 Tab 索引
    @State private var selectedTab = 0
    
    var body: some View {
        // 使用 TabView 实现底部导航栏
        TabView(selection: $selectedTab) {
            
            // --- Tab 1: Verify (核心功能) ---
            VerifyView()
                .tabItem {
                    Label("Verify", systemImage: "camera.viewfinder")
                }
                .tag(0)
            
            // --- Tab 2: Friend (社交) ---
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

// MARK: - 1. Verify View (原主页逻辑)
struct VerifyView: View {
    // 将原 ContentView 的逻辑移到这里
    @StateObject private var viewModel = TrashViewModel(classifier: RealClassifierService.shared)
    @EnvironmentObject var authVM: AuthViewModel
    
    @State private var showCamera = false
    @State private var capturedImage: UIImage?
    @State private var showReportSheet = false
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            
            VStack(spacing: 30) {
                // 顶部标题 (去掉了右上角登出按钮，因为移到了 Account 页)
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
                
                // --- 底部大按钮 (保留，作为快速入口) ---
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
        }
        .sheet(isPresented: $showCamera) {
            CameraView(selectedImage: $capturedImage)
        }
        // 兼容 iOS 14+ 的 onChange
        .onChange(of: capturedImage) { newImage in
            if let img = newImage {
                viewModel.analyzeImage(image: img)
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

// MARK: - 2. Friend View (占位)
struct FriendView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "person.2.circle")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.gray)
                
                Text("Friends")
                    .font(.title2)
                    .bold()
                
                Text("Rankings and social features coming soon!")
                    .foregroundColor(.secondary)
            }
            .navigationTitle("Friends")
        }
    }
}

// MARK: - 3. Reward View (占位)
struct RewardView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "gift.circle")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.orange)
                
                Text("Rewards")
                    .font(.title2)
                    .bold()
                
                Text("Earn points for recycling correctly!")
                    .foregroundColor(.secondary)
            }
            .navigationTitle("Rewards")
        }
    }
}

// MARK: - 4. Account View (更新版：支持绑定)
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
                            // 显示 Email 或 Phone
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
                    // --- Email 状态 ---
                    if let email = authVM.session?.user.email, !email.isEmpty {
                        HStack {
                            Label("Email", systemImage: "envelope.fill")
                            Spacer()
                            Text("Linked")
                                .foregroundColor(.secondary)
                                .font(.caption)
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
                    
                    // --- Phone 状态 ---
                    if let phone = authVM.session?.user.phone, !phone.isEmpty {
                        HStack {
                            Label("Phone", systemImage: "phone.fill")
                            Spacer()
                            Text("Linked")
                                .foregroundColor(.secondary)
                                .font(.caption)
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
            // --- 绑定手机的 Sheet ---
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
                                authVM.showOTPInput = false // 重置状态
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
                .presentationDetents([.medium])
            }
            // --- 绑定邮箱的 Sheet ---
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
// MARK: - Result Card (保持不变)
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
