import Combine
import Foundation
import Supabase

@MainActor
final class CommunityMembershipStore: ObservableObject {
    static let shared = CommunityMembershipStore()

    @Published private(set) var joinedCommunityIds: Set<String> = []
    @Published private(set) var pendingCommunityIds: Set<String> = []
    @Published private(set) var communitiesInCity: [Community] = []
    @Published private(set) var joinedCommunities: [Community] = []
    @Published private(set) var isLoadingCommunities = false

    private var communityService: CommunityService {
        CommunityService.shared
    }

    private init() {
        refreshForCurrentUser()
    }

    func refreshForCurrentUser() {
        joinedCommunityIds = []
        pendingCommunityIds = []
        joinedCommunities = []
        communitiesInCity = []
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
            let fetchedCityIDs = Set(communitiesInCity.map(\.id))
            joinedCommunityIds.subtract(fetchedCityIDs)
            pendingCommunityIds.subtract(fetchedCityIDs)

            for response in response {
                switch response.membershipStatus ?? .none {
                case .member, .admin:
                    joinedCommunityIds.insert(response.id)
                    pendingCommunityIds.remove(response.id)
                case .pending:
                    joinedCommunityIds.remove(response.id)
                    pendingCommunityIds.insert(response.id)
                case .none:
                    joinedCommunityIds.remove(response.id)
                    pendingCommunityIds.remove(response.id)
                }
            }
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
            pendingCommunityIds.subtract(joinedCommunityIds)
        } catch {
            print("❌ Get my communities error: \(error)")
        }
    }

    var adminCommunities: [Community] {
        joinedCommunities.filter(\.isAdmin)
    }

    func joinCommunity(_ community: Community) async -> (success: Bool, requiresApproval: Bool) {
        if pendingCommunityIds.contains(community.id) {
            return (true, true)
        }

        setOptimisticMembership(community: community, isMember: true)
        setPending(community: community, isPending: false)

        do {
            let result = try await communityService.joinCommunity(community.id)
            if result.success && !result.requiresApproval {
                return (true, false)
            }

            setOptimisticMembership(community: community, isMember: false)
            setPending(community: community, isPending: result.requiresApproval)
            return (result.success, result.requiresApproval)
        } catch {
            print("❌ Join community error: \(error)")
            setOptimisticMembership(community: community, isMember: false)
            setPending(community: community, isPending: false)
            return (false, false)
        }
    }

    func leaveCommunity(_ community: Community) async -> Bool {
        setOptimisticMembership(community: community, isMember: false)
        setPending(community: community, isPending: false)

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
        joinedCommunities.first(where: { $0.id == community.id })?.isAdmin
            ?? communitiesInCity.first(where: { $0.id == community.id })?.isAdmin
            ?? false
    }

    func isPending(of community: Community) -> Bool {
        pendingCommunityIds.contains(community.id)
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
            pendingCommunityIds.remove(community.id)
        } else {
            joinedCommunityIds.remove(community.id)
        }

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

    private func setPending(community: Community, isPending: Bool) {
        if isPending {
            pendingCommunityIds.insert(community.id)
        } else {
            pendingCommunityIds.remove(community.id)
        }
    }
}
