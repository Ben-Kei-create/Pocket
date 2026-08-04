import Foundation
import Supabase

protocol ServerAuthorityService: Sendable {
    nonisolated func syncMembershipEntitlement(
        _ entitlement: MembershipEntitlement
    ) async throws
    nonisolated func claimStarCoinReward(_ event: StarCoinEvent) async throws -> StarCoinAward
}

final class SupabaseServerAuthorityService: ServerAuthorityService, Sendable {
    private let client: SupabaseClient
    private let membershipFunctionName: String?

    init(client: SupabaseClient, membershipFunctionName: String?) {
        self.client = client
        self.membershipFunctionName = membershipFunctionName
    }

    func syncMembershipEntitlement(_ entitlement: MembershipEntitlement) async throws {
        guard let membershipFunctionName else { throw AppError.configuration }
        let request = MembershipSyncRequest(
            productID: entitlement.productID,
            originalTransactionID: entitlement.originalTransactionID,
            signedTransactionInfo: entitlement.signedTransactionInfo
        )
        do {
            try await client.functions.invoke(
                membershipFunctionName,
                options: FunctionInvokeOptions(body: request)
            )
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }

    func claimStarCoinReward(_ event: StarCoinEvent) async throws -> StarCoinAward {
        do {
            let rows: [StarCoinAwardDTO] = try await client
                .rpc(
                    "claim_star_coin_event",
                    params: StarCoinClaimParameters(eventKey: event.eventKey)
                )
                .execute()
                .value
            guard let award = rows.first else { throw AppError.decoding }
            return award.domainModel
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }
}

actor MockServerAuthorityService: ServerAuthorityService {
    func syncMembershipEntitlement(_ entitlement: MembershipEntitlement) async throws {}

    func claimStarCoinReward(_ event: StarCoinEvent) async throws -> StarCoinAward {
        let balanceKey = "poco.starCoinBalance"
        let claimedEventsKey = "poco.mockAuthorityRewardedCoinEvents"
        let defaults = UserDefaults.standard
        var claimedEvents = Set(defaults.stringArray(forKey: claimedEventsKey) ?? [])
        let inserted = claimedEvents.insert(event.eventKey).inserted
        let multiplier = defaults.bool(forKey: "poco.previewMembership") ? 2 : 1
        let awardedCoins = inserted ? event.mockAward * multiplier : 0
        let balance = max(0, defaults.integer(forKey: balanceKey)) + awardedCoins
        let revisionKey = "poco.mockStarWalletRevision"
        let currentRevision = Int64(defaults.integer(forKey: revisionKey))
        let nextRevision = inserted ? currentRevision + 1 : currentRevision
        defaults.set(balance, forKey: balanceKey)
        defaults.set(nextRevision, forKey: revisionKey)
        defaults.set(Array(claimedEvents), forKey: claimedEventsKey)
        return StarCoinAward(
            balance: balance,
            awardedCoins: awardedCoins,
            claimed: inserted,
            walletRevision: nextRevision
        )
    }
}

nonisolated private struct MembershipSyncRequest: Encodable, Sendable {
    let productID: String
    let originalTransactionID: String
    let signedTransactionInfo: String

    enum CodingKeys: String, CodingKey {
        case productID = "product_id"
        case originalTransactionID = "original_transaction_id"
        case signedTransactionInfo = "signed_transaction_info"
    }
}
