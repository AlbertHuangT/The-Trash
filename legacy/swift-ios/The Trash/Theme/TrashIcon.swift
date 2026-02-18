import SwiftUI
import UIKit

enum ThemeIconResolver {
    static let vibrantMap: [String: String] = [
        "camera.viewfinder": "camera.aperture",
        "flame.fill": "bolt.fill",
        "chart.bar.fill": "chart.bar.xaxis",
        "chart.bar.xaxis": "chart.xyaxis.line",
        "person.3.fill": "person.2.fill",
        "calendar.badge.clock": "calendar.circle.fill",
        "building.2.fill": "building.columns.fill",
        "building.2.crop.circle": "building.columns.circle.fill",
        "location.fill": "location.circle.fill",
        "location.slash.fill": "location.slash.circle.fill",
    ]

    static let ecoMap: [String: String] = [
        "camera.viewfinder": "camera",
        "flame.fill": "leaf.fill",
        "chart.bar.fill": "chart.bar",
        "chart.bar.xaxis": "chart.bar",
        "person.3.fill": "person.3",
        "calendar.badge.clock": "calendar",
        "calendar.circle.fill": "calendar.circle",
        "building.2.fill": "building.2",
        "building.2.crop.circle": "building.2",
        "location.fill": "location",
        "location.slash.fill": "location.slash",
        "mappin.circle.fill": "mappin",
        "checkmark.circle.fill": "checkmark.circle",
        "xmark.circle.fill": "xmark.circle",
        "plus.circle.fill": "plus.circle",
        "lock.shield.fill": "lock.shield",
        "person.crop.circle.fill": "person.crop.circle",
        "shield.fill": "shield",
        "gift.fill": "gift",
    ]

    static func resolve(systemName: String, style: VisualStyle) -> String {
        switch style {
        case .neumorphic:
            return systemName
        case .vibrantGlass:
            return vibrantMap[systemName] ?? systemName
        case .ecoPaper:
            if let mapped = ecoMap[systemName] {
                return mapped
            }
            if let plain = inferredPlainVariant(for: systemName) {
                return plain
            }
            return systemName
        }
    }

    private static func inferredPlainVariant(for systemName: String) -> String? {
        guard systemName.contains(".fill") else { return nil }
        let candidate = systemName.replacingOccurrences(of: ".fill", with: "")
        guard candidate != systemName else { return nil }
        return UIImage(systemName: candidate) == nil ? nil : candidate
    }
}

struct TrashIcon: View {
    let systemName: String
    @Environment(\.trashTheme) private var theme

    var body: some View {
        let resolvedName = ThemeIconResolver.resolve(
            systemName: systemName, style: theme.visualStyle)
        let symbol = Image(systemName: resolvedName)

        symbol
            .overlay {
                if theme.visualStyle == .ecoPaper {
                    symbol
                        .foregroundColor(Color.white.opacity(0.26))
                        .offset(x: -0.8, y: -0.8)
                        .blendMode(.screen)
                }
            }
            .overlay {
                if theme.visualStyle == .ecoPaper {
                    symbol
                        .foregroundColor(Color.black.opacity(0.30))
                        .offset(x: 1.2, y: 1.2)
                        .blendMode(.multiply)
                }
            }
    }
}
