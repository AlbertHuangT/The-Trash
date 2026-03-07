import Combine
import Foundation

@MainActor
final class CommunityMembershipStore: ObservableObject {
    static let shared = CommunityMembershipStore()

    @Published private(set) var joinedCommunityIds: Set<String> = []
    @Published private(set) var communitiesInCity: [Community] = []
    @Published private(set) var joinedCommunities: [Community] = []
    @Published private(set) var isLoadingCommunities = false

    private let joinedCommunitiesKey = "joinedCommunityIds"

    private var communityService: CommunityService {
        CommunityService.shared
    }

    private init() {
        loadSavedJoinedCommunityIds()
    }

    private func loadSavedJoinedCommunityIds() {
        if let ids = UserDefaults.standard.array(forKey: joinedCommunitiesKey) as? [String] {
            joinedCommunityIds = Set(ids)
        }
    }

    func clearCommunitiesInCity() {
        communitiesInCity = []
    }

    func loadCommunitiesForCity(_ city: String) async {
        isLoadingCommunities = true
        defer { isLoadingCommunities = false }

        do {
            let response = try await communityService.getCommunitiesByCity(city)
            communitiesInCity = response.map { Community(from: $0) }

            for community in communitiesInCity where community.isMember {
                joinedCommunityIds.insert(community.id)
            }
            saveJoinedCommunities()
        } catch {
            print("❌ Get communities error: \(error)")
        }
    }

    func loadMyCommunities() async {
        let showLoading = joinedCommunities.isEmpty
        if showLoading {
            isLoadingCommunities = true
        }
        defer { isLoadingCommunities = false }

        do {
            let response = try await communityService.getMyCommunities()
            joinedCommunities = response.map { resp in
                Community(
                    id: resp.id,
                    name: resp.name,
                    city: resp.city,
                    state: resp.state ?? "",
                    description: resp.description ?? "",
                    memberCount: resp.memberCount,
                    latitude: 0,
                    longitude: 0,
                    isMember: true,
                    isAdmin: resp.isAdmin
                )
            }

            joinedCommunityIds = Set(joinedCommunities.map(\.id))
            saveJoinedCommunities()
        } catch {
            print("❌ Get my communities error: \(error)")
        }
    }

    var adminCommunities: [Community] {
        joinedCommunities.filter(\.isAdmin)
    }

    func joinCommunity(_ community: Community) async -> (success: Bool, requiresApproval: Bool) {
        setOptimisticMembership(community: community, isMember: true)

        do {
            let result = try await communityService.joinCommunity(community.id)
            if result.success && !result.requiresApproval {
                return (true, false)
            }

            setOptimisticMembership(community: community, isMember: false)
            return (result.success, result.requiresApproval)
        } catch {
            print("❌ Join community error: \(error)")
            setOptimisticMembership(community: community, isMember: false)
            return (false, false)
        }
    }

    func leaveCommunity(_ community: Community) async -> Bool {
        setOptimisticMembership(community: community, isMember: false)

        do {
            let success = try await communityService.leaveCommunity(community.id)
            if !success {
                setOptimisticMembership(community: community, isMember: true)
            }
            return success
        } catch {
            print("❌ Leave community error: \(error)")
            setOptimisticMembership(community: community, isMember: true)
            return false
        }
    }

    func isMember(of community: Community) -> Bool {
        joinedCommunityIds.contains(community.id)
    }

    func isAdmin(of community: Community) -> Bool {
        joinedCommunities.first(where: { $0.id == community.id })?.isAdmin ?? false
    }

    func getJoinedCommunities() -> [Community] {
        joinedCommunities
    }

    func getCommunitiesNearLocation(_ location: UserLocation? = nil) -> [Community] {
        communitiesInCity
    }

    func searchCommunities(query: String, inCity: String? = nil) -> [Community] {
        var results = communitiesInCity

        if !query.isEmpty {
            let q = query.lowercased()
            results = results.filter {
                $0.name.lowercased().contains(q)
                    || $0.description.lowercased().contains(q)
            }
        }

        return results
    }

    private func setOptimisticMembership(community: Community, isMember: Bool) {
        if isMember {
            joinedCommunityIds.insert(community.id)
        } else {
            joinedCommunityIds.remove(community.id)
        }
        saveJoinedCommunities()

        if let index = communitiesInCity.firstIndex(where: { $0.id == community.id }) {
            if communitiesInCity[index].isMember != isMember {
                communitiesInCity[index].isMember = isMember
                communitiesInCity[index].memberCount += isMember ? 1 : -1
                if communitiesInCity[index].memberCount < 0 {
                    communitiesInCity[index].memberCount = 0
                }
            }
        }

        if isMember {
            if !joinedCommunities.contains(where: { $0.id == community.id }) {
                var newCommunity = community
                newCommunity.isMember = true
                if let updated = communitiesInCity.first(where: { $0.id == community.id }) {
                    newCommunity = updated
                } else {
                    newCommunity.memberCount += 1
                }
                joinedCommunities.append(newCommunity)
            }
        } else {
            joinedCommunities.removeAll { $0.id == community.id }
        }
    }

    private func saveJoinedCommunities() {
        UserDefaults.standard.set(Array(joinedCommunityIds), forKey: joinedCommunitiesKey)
    }
}
