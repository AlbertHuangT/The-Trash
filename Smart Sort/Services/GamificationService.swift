import Foundation
import Supabase

protocol GamificationServicing: AnyObject {
    func awardCredits(_ amount: Int) async throws
    func awardVerifyCredits(_ amount: Int) async throws
}

@MainActor
final class GamificationService: GamificationServicing {
    static let shared = GamificationService()

    private let client = SupabaseManager.shared.client
    private let achievementService = AchievementService.shared

    private init() {}

    func awardCredits(_ amount: Int) async throws {
        _ = try await client.rpc("increment_credits", params: ["amount": amount]).execute()
    }

    func awardVerifyCredits(_ amount: Int) async throws {
        try await awardCredits(amount)
        await achievementService.incrementTotalScans()
        await achievementService.checkMultipleTriggers([
            "first_scan",
            "scans_10",
            "scans_50",
            "credits_100",
            "credits_500",
            "credits_2000"
        ])
    }
}
