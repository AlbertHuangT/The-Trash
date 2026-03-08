import SwiftUI

struct BadgeAchievementsHubView: View {
    enum Segment: String, CaseIterable, Identifiable {
        case badges
        case achievements

        var id: String { rawValue }
        var title: String {
            switch self {
            case .badges: return "Badges"
            case .achievements: return "Achievements"
            }
        }

        var icon: String {
            switch self {
            case .badges: return "star.circle.fill"
            case .achievements: return "trophy.fill"
            }
        }
    }

    @State private var selectedSegment: Segment = .badges
    private let theme = TrashTheme()

    var body: some View {
        VStack(spacing: theme.layout.sectionSpacing) {
            TrashSegmentedControl(
                options: Segment.allCases.map {
                    TrashSegmentOption(value: $0, title: $0.title, icon: $0.icon)
                },
                selection: $selectedSegment
            )
            .padding(.horizontal, theme.layout.screenInset)
            .padding(.top, theme.layout.elementSpacing)

            Group {
                switch selectedSegment {
                case .badges:
                    BadgePickerView(showsNavigationTitle: false)
                        .transition(.opacity)
                case .achievements:
                    AchievementsListView(showsNavigationTitle: false)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, theme.spacing.xs)
        }
        .trashScreenBackground()
        .navigationTitle("Badges & Achievements")
        .animation(.easeInOut, value: selectedSegment)
    }
}
