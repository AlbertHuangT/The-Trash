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
    @Environment(\.trashTheme) private var theme

    var body: some View {
        VStack(spacing: theme.layout.elementSpacing) {
            HStack(spacing: theme.layout.rowContentSpacing) {
                Text(result.itemName)
                    .trashTextRole(.headline, compact: true)
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
                .trashTextRole(.body, color: theme.palette.textSecondary, compact: true)
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
    @Environment(\.trashTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.layout.elementSpacing) {
            Text("Help us improve")
                .trashTextRole(.headline, compact: true)

            Text("What was the item? Your correction helps the AI learn.")
                .trashTextRole(.body, color: theme.palette.textSecondary, compact: true)
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
    @Environment(\.trashTheme) private var theme

    var body: some View {
        VStack(spacing: theme.layout.elementSpacing) {
            TrashIcon(systemName: "exclamationmark.octagon.fill")
                .font(theme.typography.headline)
                .foregroundColor(theme.semanticDanger)

            Text("Analysis Error")
                .trashTextRole(.headline, compact: true)
                .fontWeight(.bold)

            Text(message)
                .trashTextRole(.body, color: theme.palette.textSecondary, compact: true)
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

// MARK: - Scanning Overlay (ShipSwift SWScanningOverlay)

struct SWScanningOverlay<Content: View>: View {
    var gridOpacity: Double = 0.2
    var bandOpacity: Double = 0.3
    var bandHeightRatio: CGFloat = 0.2
    var gridSpacing: CGFloat = 16
    var speed: Double = 2.0
    @ViewBuilder let content: () -> Content
    @State private var startDate = Date.now

    init(
        gridOpacity: Double = 0.2,
        bandOpacity: Double = 0.3,
        bandHeightRatio: CGFloat = 0.2,
        gridSpacing: CGFloat = 16,
        speed: Double = 2.0,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.gridOpacity = gridOpacity
        self.bandOpacity = bandOpacity
        self.bandHeightRatio = bandHeightRatio
        self.gridSpacing = gridSpacing
        self.speed = speed
        self.content = content
    }

    var body: some View {
        content()
            .overlay {
                TimelineView(.animation) { timeline in
                    let t = timeline.date.timeIntervalSince(startDate)
                    GeometryReader { geo in
                        let size = geo.size
                        ZStack {
                            Canvas { ctx, _ in
                                let phase = CGFloat(t * 0.8)
                                let dx = sin(phase) * 3
                                let dy = cos(phase * 0.9) * 3
                                var path = Path()
                                let step = max(10, gridSpacing)
                                var x: CGFloat = -step
                                while x <= size.width + step {
                                    let xx = x + dx + sin((x / 80) + phase) * 1.5
                                    path.move(to: CGPoint(x: xx, y: 0))
                                    path.addLine(to: CGPoint(x: xx, y: size.height))
                                    x += step
                                }
                                var y: CGFloat = -step
                                while y <= size.height + step {
                                    let yy = y + dy + cos((y / 80) + phase) * 1.5
                                    path.move(to: CGPoint(x: 0, y: yy))
                                    path.addLine(to: CGPoint(x: size.width, y: yy))
                                    y += step
                                }
                                ctx.stroke(path, with: .color(.white.opacity(gridOpacity)), lineWidth: 1)
                            }
                            .blendMode(.screen)
                            scanBand(size: size, time: t)
                            noiseOverlay(time: t).opacity(0.06).blendMode(.overlay)
                        }
                        .compositingGroup()
                    }
                }
            }
    }

    private func scanBand(size: CGSize, time t: Double) -> some View {
        let p = CGFloat((t * (0.22 * speed)).truncatingRemainder(dividingBy: 1.0))
        let bandH = size.height * bandHeightRatio
        let y = -bandH + (size.height + bandH * 2) * p
        return ZStack {
            Rectangle()
                .fill(LinearGradient(stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: .white.opacity(bandOpacity * 0.4), location: 0.25),
                    .init(color: .white.opacity(bandOpacity), location: 0.5),
                    .init(color: .white.opacity(bandOpacity * 0.4), location: 0.75),
                    .init(color: .clear, location: 1.0),
                ], startPoint: .top, endPoint: .bottom))
                .frame(height: bandH)
                .position(x: size.width / 2, y: y)
                .blendMode(.screen)
            Rectangle()
                .fill(Color.white.opacity(bandOpacity * 0.65))
                .frame(height: 2)
                .position(x: size.width / 2, y: y)
                .blur(radius: 0.6)
                .blendMode(.screen)
        }
    }

    private func noiseOverlay(time t: Double) -> some View {
        LinearGradient(
            colors: [.white.opacity(0.0), .white.opacity(1.0), .white.opacity(0.0)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        .scaleEffect(1.6)
        .offset(x: sin(t * 0.9) * 20, y: cos(t * 1.1) * 20)
        .blur(radius: 12)
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
