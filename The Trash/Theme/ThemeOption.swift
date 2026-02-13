import SwiftUI

enum ThemeOption: String, CaseIterable, Identifiable {
    case neumorphic
    case vibrant
    case ecoSkeuomorphic

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .neumorphic: return "Neumorphic"
        case .vibrant: return "Vibrant Night"
        case .ecoSkeuomorphic: return "Eco-Skeuomorphism"
        }
    }

    var description: String {
        switch self {
        case .neumorphic:
            return "Soft shadows, tactile surfaces."
        case .vibrant:
            return "High-contrast neon energy."
        case .ecoSkeuomorphic:
            return "Kraft paper depth with die-cut cardboard layers."
        }
    }

    var icon: String {
        switch self {
        case .neumorphic: return "circle.grid.2x2"
        case .vibrant: return "sparkles"
        case .ecoSkeuomorphic: return "leaf.fill"
        }
    }

    var previewGradient: [Color] {
        switch self {
        case .neumorphic:
            return [Color(red: 0.35, green: 0.51, blue: 0.96), Color(red: 0.63, green: 0.72, blue: 0.99)]
        case .vibrant:
            return [Color(red: 0.96, green: 0.36, blue: 0.67), Color(red: 0.31, green: 0.87, blue: 0.99)]
        case .ecoSkeuomorphic:
            return [Color(red: 0.82, green: 0.73, blue: 0.55), Color(red: 0.31, green: 0.46, blue: 0.27)]
        }
    }

    func makeTheme() -> TrashTheme {
        switch self {
        case .neumorphic: return NeumorphicTheme()
        case .vibrant: return VibrantTheme()
        case .ecoSkeuomorphic: return EcoSkeuomorphicTheme()
        }
    }
}
