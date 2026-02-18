//
//  VerifyComponents.swift
//  The Trash
//

import SwiftUI

// MARK: - Enhanced Swipeable Card
struct EnhancedSwipeableCard: View {
    let result: TrashAnalysisResult
    @Binding var offset: CGSize
    let onSwipe: (SwipeDirection) -> Void
    @Environment(\.trashTheme) private var theme

    var body: some View {
        ZStack {
            VStack(spacing: 12) {
                // Header: Item Name
                HStack {
                    Text(result.itemName)
                        .font(theme.typography.headline)
                        .foregroundColor(theme.palette.textPrimary)
                    Spacer()
                    Text("\(Int(result.confidence * 100))%")
                        .font(theme.typography.caption)
                        .foregroundColor(result.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .trashCard(cornerRadius: 8)
                }

                Divider().background(theme.palette.divider)

                // Category Badge
                HStack {
                    TrashIcon(systemName: categoryIcon)
                    Text(result.category)
                }
                .font(theme.typography.subheadline)
                .fontWeight(.bold)
                .trashOnAccentForeground()
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(result.color)
                .clipShape(Capsule())

                // Action Tip
                Text(result.actionTip)
                    .font(theme.typography.body)
                    .foregroundColor(theme.palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)

                Spacer(minLength: 0)

                // Swipe hints
                HStack {
                    TrashLabel("Correction", icon: "arrow.left")
                        .foregroundColor(theme.semanticWarning)
                    Spacer()
                    TrashLabel("Confirm", icon: "arrow.right")
                        .foregroundColor(theme.semanticSuccess)
                }
                .font(.caption2.bold())
            }
            .padding(24)
            .trashCard(cornerRadius: 28)
        }
        .offset(x: offset.width, y: offset.height * 0.4)
        .rotationEffect(.degrees(Double(offset.width / 20)))
        .gesture(
            DragGesture()
                .onChanged { gesture in
                    offset = gesture.translation
                }
                .onEnded { _ in
                    if offset.width > 100 {
                        onSwipe(.right)
                    } else if offset.width < -100 {
                        onSwipe(.left)
                    } else {
                        withAnimation(.spring()) {
                            offset = .zero
                        }
                    }
                }
        )
    }

    private var categoryIcon: String {
        switch result.category.lowercased() {
        case let c where c.contains("recycle"): return "arrow.3.trianglepath"
        case let c where c.contains("compost"): return "leaf.fill"
        case let c where c.contains("hazardous"): return "exclamationmark.triangle.fill"
        default: return "trash.fill"
        }
    }
}

// MARK: - Enhanced Feedback Form
struct EnhancedFeedbackForm: View {
    @Binding var itemName: String
    @Environment(\.trashTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Help us improve")
                .font(theme.typography.headline)
                .foregroundColor(theme.palette.textPrimary)

            Text("What was the item? Your correction helps the AI learn.")
                .font(theme.typography.caption)
                .foregroundColor(theme.palette.textSecondary)

            TrashFormTextField(
                title: "Correct item name...",
                text: $itemName,
                textInputAutocapitalization: .never
            )
        }
        .padding(24)
        .trashCard(cornerRadius: 28)
    }
}

// MARK: - Error Card
struct ErrorCard: View {
    let message: String
    let onRetry: () -> Void
    @Environment(\.trashTheme) private var theme

    var body: some View {
        VStack(spacing: 16) {
            TrashIcon(systemName: "exclamationmark.octagon.fill")
                .font(.system(size: 44))
                .foregroundColor(theme.semanticDanger)

            Text("Analysis Error")
                .font(theme.typography.headline)
                .foregroundColor(theme.palette.textPrimary)

            Text(message)
                .font(theme.typography.caption)
                .foregroundColor(theme.palette.textSecondary)
                .multilineTextAlignment(.center)

            TrashButton(baseColor: theme.accents.blue, action: onRetry) {
                Text("Try Again")
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
            }
        }
        .padding(24)
        .trashCard(cornerRadius: 28)
    }
}

enum SwipeDirection {
    case left, right
}

// MARK: - Scan Line Overlay
struct ScanLineOverlay: View {
    @State private var scanPos: CGFloat = 0
    @Environment(\.trashTheme) private var theme

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                // Border
                RoundedRectangle(cornerRadius: 24)
                    .stroke(theme.accents.blue.opacity(0.3), lineWidth: 2)

                // Moving line
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, theme.accents.blue.opacity(0.5), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 40)
                    .offset(y: scanPos)
                    .onAppear {
                        withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: true)) {
                            scanPos = geo.size.height - 40
                        }
                    }
            }
        }
    }
}
