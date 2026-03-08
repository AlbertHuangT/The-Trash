import Foundation
import Supabase

enum VerifyRewardKind: String, Sendable {
    case confirmed
    case correction
}

struct VerifyRewardResponse: Decodable {
    let awarded: Bool
    let reason: String?
    let creditsAwarded: Int
    let totalCredits: Int?
    let totalScans: Int?

    enum CodingKeys: String, CodingKey {
        case awarded
        case reason
        case creditsAwarded = "credits_awarded"
        case totalCredits = "total_credits"
        case totalScans = "total_scans"
    }
}

protocol GamificationServicing: AnyObject {
    func awardVerifyReward(scanId: UUID, kind: VerifyRewardKind) async throws -> VerifyRewardResponse
}

@MainActor
final class GamificationService: GamificationServicing {
    static let shared = GamificationService()

    private let client = SupabaseManager.shared.client

    private init() {}

    func awardVerifyReward(scanId: UUID, kind: VerifyRewardKind) async throws -> VerifyRewardResponse {
        try await client
            .rpc(
                "award_verify_reward",
                params: [
                    "p_scan_id": scanId.uuidString,
                    "p_reward_kind": kind.rawValue,
                ]
            )
            .execute()
            .value
    }
}
