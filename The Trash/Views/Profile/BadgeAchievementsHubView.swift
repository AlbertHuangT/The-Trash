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

    var body: some View {
        VStack(spacing: 16) {
            Picker("Segment", selection: $selectedSegment) {
                ForEach(Segment.allCases) { segment in
                    Label(segment.title, systemImage: segment.icon)
                        .tag(segment)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 12)

            Divider()
                .background(Color.neuDivider)

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
        }
        .background(
            ThemeBackgroundView()
                .ignoresSafeArea()
        )
        .navigationTitle("Badges & Achievements")
        .animation(.easeInOut, value: selectedSegment)
    }
}
