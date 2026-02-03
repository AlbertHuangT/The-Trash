//
//  ContentView.swift
//  The Trash
//
//  Created by Albert Huang on 1/20/26.
//

import SwiftUI

struct ContentView: View {
    // ⚠️ Key point: Here we want to use RealClassifierService!
    // This way the app will load the TrashModel you just added
    @StateObject private var viewModel = TrashViewModel(classifier: RealClassifierService())
    
    // Control the presentation of the camera page
    @State private var showCamera = false
    // Temporarily store the captured photo
    @State private var capturedImage: UIImage?
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            
            VStack(spacing: 30) {
                Text("The Trash")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 40)
                    .foregroundColor(.primary)
                
                // --- Viewfinder area ---
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color(.tertiarySystemFill))
                        .frame(height: 350)
                        .shadow(radius: 10)
                    
                    // A. Show spinner if analyzing
                    if viewModel.appState == .analyzing {
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(CircularProgressViewStyle(tint: .primary))
                            
                    // B. Show photo preview if a photo was taken
                    } else if let image = capturedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 350)
                            .cornerRadius(24)
                            
                    // C. Default state: show camera icon
                    } else {
                        VStack {
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 60))
                                .foregroundColor(.primary)
                            Text("Tap below to take a photo")
                                .foregroundColor(.secondary)
                                .padding(.top, 10)
                        }
                    }
                }
                .padding(.horizontal)
                
                // --- Result card ---
                if case .finished(let result) = viewModel.appState {
                    ResultCard(result: result)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                Spacer()
                
                // --- Bottom button ---
                Button(action: {
                    // Click button -> show camera
                    showCamera = true
                }) {
                    HStack {
                        Image(systemName: "camera.fill")
                        Text("Identify by Photo")
                    }
                    .font(.title3)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
        // --- Sheet logic ---
        .sheet(isPresented: $showCamera) {
            // When camera is dismissed...
            CameraView(selectedImage: $capturedImage)
        }
        // --- Listen for photo changes ---
        // Once capturedImage has a value (a photo was just taken), immediately send it to AI for analysis
        .onChange(of: capturedImage) { oldValue, newImage in
            if let img = newImage {
                viewModel.analyzeImage(image: img)
            }
        }
        .animation(.spring(), value: viewModel.appState)
    }
}

// Result card remains unchanged except for UI strings and colors
struct ResultCard: View {
    let result: TrashAnalysisResult
    
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
                    .foregroundColor(.primary)
                Text(result.itemName)
                    .foregroundColor(.primary)
            }
            HStack(alignment: .top) {
                Text("Suggestion:")
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Text(result.actionTip)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }
}


#Preview {
    ContentView()
}

