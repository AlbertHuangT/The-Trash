import SwiftUI

struct ThemeBackgroundView: View {
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        Group {
            switch themeManager.currentOption {
            case .ecoSkeuomorphic:
                PaperTextureView()
            default:
                Color.neuBackground
            }
        }
    }
}
