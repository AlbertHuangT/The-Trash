//
//  VerifyComponents.swift
//  The Trash
//
//  Extracted from VerifyView.swift
//

import SwiftUI

// MARK: - Swipe Direction

enum SwipeDirection {
    case left
    case right
}

// MARK: - Scan Line Overlay

struct ScanLineOverlay: View {
    @State private var offset: CGFloat = -200

    var body: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, .blue.opacity(0.3), .cyan.opacity(0.5), .blue.opacity(0.3), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 3)
                .offset(y: offset)
                .onAppear {
                    withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                        offset = geo.size.height + 200
                    }
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28))
    }
}

// MARK: - Enhanced Swipeable Card

struct EnhancedSwipeableCard: View {
    let result: TrashAnalysisResult
    @Binding var offset: CGSize
    var onSwiped: (SwipeDirection) -> Void

    var body: some View {
        EnhancedResultCard(result: result)
            .overlay(
                ZStack {
                    if offset.width > 0 {
                        EnhancedCorrectOverlay()
                            .opacity(Double(offset.width / 150))
                    } else if offset.width < 0 {
                        EnhancedIncorrectOverlay()
                            .opacity(Double(-offset.width / 150))
                    }
                }
                .allowsHitTesting(false)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.1), radius: 12, y: 6)
            .offset(x: offset.width)
            .rotationEffect(.degrees(Double(offset.width / 20)))
            .padding(.horizontal, 16)
            .gesture(DragGesture()
                .onChanged { gesture in
                    offset = gesture.translation
                }
                .onEnded { gesture in
                    if gesture.translation.width < -100 { onSwiped(.left) }
                    else if gesture.translation.width > 100 { onSwiped(.right) }
                    else { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { offset = .zero } }
                }
            )
    }
}

// MARK: - Enhanced Result Card

struct EnhancedResultCard: View {
    let result: TrashAnalysisResult

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(result.color.opacity(0.15))
                    .frame(width: 60, height: 60)

                Image(systemName: iconForCategory(result.category))
                    .font(.system(size: 26))
                    .foregroundColor(result.color)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(result.category)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(result.color)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(result.color.opacity(0.1))
                        .cornerRadius(8)

                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: "brain.head.profile")
                            .font(.caption2)
                        Text("\(Int(result.confidence * 100))%")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(.secondary)
                }

                Text(result.itemName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)

                Text(result.actionTip)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(minHeight: 150)
        .background(Color(.secondarySystemGroupedBackground))
    }

    private func iconForCategory(_ category: String) -> String {
        switch category {
        case _ where category.contains("Recycl") || category.contains("Blue"): return "arrow.3.trianglepath"
        case _ where category.contains("Compost") || category.contains("Green"): return "leaf.fill"
        case _ where category.contains("Hazard"): return "exclamationmark.triangle.fill"
        case _ where category.contains("Electronic"): return "bolt.fill"
        default: return "trash.fill"
        }
    }
}

// MARK: - Correct Overlay

struct EnhancedCorrectOverlay: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [.green.opacity(0.95), .mint.opacity(0.95)], startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44))
                Text("Correct!")
                    .font(.headline.bold())
                Text("Swipe right to confirm")
                    .font(.caption2)
                    .opacity(0.8)
            }
            .foregroundColor(.white)
        }
    }
}

// MARK: - Incorrect Overlay

struct EnhancedIncorrectOverlay: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [.red.opacity(0.95), .orange.opacity(0.95)], startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(spacing: 8) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 44))
                Text("Incorrect?")
                    .font(.headline.bold())
                Text("Swipe left to correct")
                    .font(.caption2)
                    .opacity(0.8)
            }
            .foregroundColor(.white)
        }
    }
}

// MARK: - Error Card

struct ErrorCard: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundStyle(
                    LinearGradient(colors: [.orange, .red], startPoint: .top, endPoint: .bottom)
                )

            Text("Something went wrong")
                .font(.headline)

            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: onRetry) {
                Label("Try Again", systemImage: "arrow.clockwise")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(20)
            }
        }
        .padding(24)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
        .padding(.horizontal, 16)
    }
}

// MARK: - Enhanced Feedback Form

struct EnhancedFeedbackForm: View {
    @Binding var itemName: String

    var body: some View {
        VStack(spacing: 16) {
            Text("What is this item?")
                .font(.subheadline.bold())
                .foregroundColor(.secondary)

            HStack {
                Image(systemName: "tag.fill")
                    .foregroundColor(.secondary)
                TextField("e.g. Plastic bottle, Battery...", text: $itemName)
            }
            .padding(12)
            .background(Color(.tertiarySystemGroupedBackground))
            .cornerRadius(12)
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.08), radius: 10, y: 5)
        .padding(.horizontal, 16)
    }
}
