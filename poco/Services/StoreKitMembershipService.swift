import Foundation
import StoreKit

protocol MembershipPurchaseService: Sendable {
    func fetchOffer() async throws -> MembershipOffer?
    func purchase() async throws -> MembershipPurchaseResult
    func restore() async throws -> Bool
}

actor StoreKitMembershipService: MembershipPurchaseService {
    private let productID: String

    init(productID: String) {
        self.productID = productID
    }

    func fetchOffer() async throws -> MembershipOffer? {
        guard let product = try await product() else { return nil }
        return MembershipOffer(productID: product.id, displayPrice: product.displayPrice)
    }

    func purchase() async throws -> MembershipPurchaseResult {
        guard let product = try await product() else {
            throw AppError.purchase
        }

        switch try await product.purchase() {
        case .success(let verification):
            let transaction = try verified(verification)
            await transaction.finish()
            return .purchased
        case .pending:
            return .pending
        case .userCancelled:
            return .cancelled
        @unknown default:
            throw AppError.purchase
        }
    }

    func restore() async throws -> Bool {
        try await AppStore.sync()
        for await entitlement in Transaction.currentEntitlements {
            let transaction = try verified(entitlement)
            if transaction.productID == productID,
               transaction.revocationDate == nil,
               transaction.expirationDate.map({ $0 > .now }) ?? true {
                return true
            }
        }
        return false
    }

    private func product() async throws -> Product? {
        guard !productID.isEmpty else { return nil }
        return try await Product.products(for: [productID]).first
    }

    private func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):
            return value
        case .unverified:
            throw AppError.purchase
        }
    }
}

struct DisabledMembershipPurchaseService: MembershipPurchaseService {
    func fetchOffer() async throws -> MembershipOffer? { nil }
    func purchase() async throws -> MembershipPurchaseResult { throw AppError.purchase }
    func restore() async throws -> Bool { false }
}
