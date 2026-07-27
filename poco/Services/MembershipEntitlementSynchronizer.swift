import Foundation
import Supabase

protocol MembershipEntitlementSynchronizing: Sendable {
    nonisolated func sync(_ entitlement: MembershipEntitlement) async throws
}

final class SupabaseMembershipEntitlementSynchronizer: MembershipEntitlementSynchronizing,
    Sendable {
    private let client: SupabaseClient
    private let functionName: String

    init(client: SupabaseClient, functionName: String) {
        self.client = client
        self.functionName = functionName
    }

    func sync(_ entitlement: MembershipEntitlement) async throws {
        let request = MembershipSyncRequest(
            productID: entitlement.productID,
            originalTransactionID: entitlement.originalTransactionID,
            signedTransactionInfo: entitlement.signedTransactionInfo
        )
        do {
            try await client.functions.invoke(
                functionName,
                options: FunctionInvokeOptions(body: request)
            )
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
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
