//
//  VerifyComponents.swift
//  Smart Sort
//

import SwiftUI

// MARK: - Enhanced Swipeable Card
struct EnhancedSwipeableCard: View {
    let result: TrashAnalysisResult
    @Binding var offset: CGSize
    let onSwipe: (SwipeDirection) -> Void
    private let theme = TrashTheme()

    var body: some View {
        VStack(spacing: theme.layout.elementSpacing) {
            HStack(spacing: theme.layout.rowContentSpacing) {
                Text(result.itemName)
                    .font(theme.typography.subheadline)
                    .foregroundColor(theme.palette.textPrimary)
                    .lineLimit(1)

                Spacer(minLength: theme.spacing.sm)

                Text("\(Int(result.confidence * 100))%")
                    .font(theme.typography.caption)
                    .fontWeight(.bold)
                    .foregroundColor(theme.palette.textPrimary)
                    .padding(.horizontal, theme.layout.compactControlHorizontalInset)
                    .frame(minHeight: theme.components.compactControlHeight)
                    .background(
                        RoundedRectangle(cornerRadius: theme.corners.small, style: .continuous)
                            .fill(result.color.opacity(0.18))
                    )
            }

            Divider().background(theme.palette.divider)

            HStack(spacing: theme.spacing.sm) {
                TrashPill(
                    title: result.category,
                    icon: categoryIcon,
                    color: result.color,
                    isSelected: false
                )

                Spacer()
            }

            Text(result.actionTip)
                .font(theme.typography.caption)
                .foregroundColor(theme.palette.textSecondary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(2)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: theme.layout.elementSpacing) {
                    swipeHint(title: "Correction", icon: "arrow.left", color: theme.semanticWarning)
                    Spacer(minLength: theme.spacing.sm)
                    swipeHint(title: "Confirm", icon: "arrow.right", color: theme.semanticSuccess)
                }

                VStack(spacing: theme.spacing.sm) {
                    swipeHint(title: "Correction", icon: "arrow.left", color: theme.semanticWarning)
                    swipeHint(title: "Confirm", icon: "arrow.right", color: theme.semanticSuccess)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(theme.components.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: theme.layout.prominentCardCornerRadius, style: .continuous)
                .fill(theme.surfaceBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: theme.layout.prominentCardCornerRadius, style: .continuous)
                        .stroke(theme.palette.divider.opacity(0.85), lineWidth: 1)
                )
        )
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
    private let theme = TrashTheme()

    var body: some View {
        VStack(alignment: .leading, spacing: theme.layout.elementSpacing) {
            Text("Help us improve")
                .font(theme.typography.subheadline)
                .foregroundColor(theme.palette.textPrimary)

            Text("What was the item? Your correction helps the AI learn.")
                .font(theme.typography.caption)
                .foregroundColor(theme.palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            TrashFormTextField(
                title: "Correct item name...",
                text: $itemName,
                textInputAutocapitalization: .never
            )
        }
        .padding(theme.components.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: theme.layout.prominentCardCornerRadius, style: .continuous)
                .fill(theme.surfaceBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: theme.layout.prominentCardCornerRadius, style: .continuous)
                        .stroke(theme.palette.divider.opacity(0.85), lineWidth: 1)
                )
        )
    }
}

// MARK: - Error Card
struct ErrorCard: View {
    let message: String
    let onRetry: () -> Void
    private let theme = TrashTheme()

    var body: some View {
        VStack(spacing: theme.layout.elementSpacing) {
            TrashIcon(systemName: "exclamationmark.octagon.fill")
                .font(.system(size: 34))
                .foregroundColor(theme.semanticDanger)

            Text("Analysis Error")
                .font(theme.typography.subheadline)
                .fontWeight(.bold)
                .foregroundColor(theme.palette.textPrimary)

            Text(message)
                .font(theme.typography.caption)
                .foregroundColor(theme.palette.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            TrashButton(baseColor: theme.accents.blue, action: onRetry) {
                Text("Try Again")
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(theme.components.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: theme.layout.prominentCardCornerRadius, style: .continuous)
                .fill(theme.surfaceBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: theme.layout.prominentCardCornerRadius, style: .continuous)
                        .stroke(theme.palette.divider.opacity(0.85), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
        )
    }
}

enum SwipeDirection {
    case left, right
}

// MARK: - Scan Line Overlay
struct ScanLineOverlay: View {
    @State private var scanPos: CGFloat = 0
    private let theme = TrashTheme()

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                // Border
                RoundedRectangle(cornerRadius: theme.layout.prominentCardCornerRadius)
                    .stroke(theme.accents.blue.opacity(0.14), lineWidth: 1)

                // Moving line
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, theme.accents.blue.opacity(0.36), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 28)
                    .offset(y: scanPos)
                    .onAppear {
                        withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: true)) {
                            scanPos = geo.size.height - 28
                        }
                    }
            }
        }
    }
}

extension EnhancedSwipeableCard {
    private func swipeHint(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 4) {
            TrashIcon(systemName: icon)
            Text(title)
        }
        .font(.caption2.bold())
        .foregroundColor(color)
        .padding(.horizontal, theme.spacing.sm)
        .frame(minHeight: 28)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
        .lineLimit(1)
    }
}
