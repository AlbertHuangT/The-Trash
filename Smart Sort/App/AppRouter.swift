import Combine
import Foundation

@MainActor
final class AppRouter: ObservableObject {
    static let shared = AppRouter()

    enum Tab: Hashable {
        case verify
        case arena
        case leaderboard
        case community
    }

    enum Sheet: Identifiable, Equatable {
        case account
        case createEvent
        case createCommunity

        var id: String {
            switch self {
            case .account: return "account"
            case .createEvent: return "createEvent"
            case .createCommunity: return "createCommunity"
            }
        }
    }

    @Published var selectedTab: Tab = .verify
    @Published var activeSheet: Sheet?
    @Published var pendingChallengeId: UUID?

    private init() {}

    func presentAccount() {
        activeSheet = .account
    }

    func presentCreateEvent() {
        selectedTab = .community
        activeSheet = .createEvent
    }

    func presentCreateCommunity() {
        selectedTab = .community
        activeSheet = .createCommunity
    }

    func dismissSheet() {
        activeSheet = nil
    }

    @discardableResult
    func handleDeepLink(url: URL) -> Bool {
        guard url.scheme == "smartsort",
              url.host == "challenge",
              let idString = url.pathComponents.dropFirst().first,
              let challengeId = UUID(uuidString: idString) else {
            return false
        }

        selectedTab = .arena
        pendingChallengeId = challengeId
        return true
    }

    func clearPendingChallenge() {
        pendingChallengeId = nil
    }
}
