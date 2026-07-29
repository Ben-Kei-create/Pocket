import Foundation

nonisolated enum StarStoreItemKind: String, Codable, CaseIterable, Sendable {
    case bubbleColor = "bubble_color"
    case projectBackground = "project_background"
    case profileBadge = "profile_badge"
}

nonisolated struct StarStoreItem: Identifiable, Equatable, Codable, Sendable {
    let id: String
    let kind: StarStoreItemKind
    let title: String
    let summary: String
    let priceCoins: Int
    let assetName: String?
    let appearanceValue: String?
    let requiresPro: Bool
    let sortOrder: Int

    var systemSymbolName: String? {
        guard let assetName, assetName.hasPrefix("sf:") else { return nil }
        return String(assetName.dropFirst(3))
    }

    var imageAssetName: String? {
        guard let assetName, !assetName.hasPrefix("sf:") else { return nil }
        return assetName
    }
}

nonisolated struct ProjectDecoration: Equatable, Sendable {
    let backgroundItemID: String?
    let badgeItemIDsBySlot: [Int: String]

    static let empty = Self(backgroundItemID: nil, badgeItemIDsBySlot: [:])

    func badgeItemID(slot: Int) -> String? {
        badgeItemIDsBySlot[slot]
    }
}

nonisolated struct StarStorePurchaseResult: Equatable, Sendable {
    let itemID: String
    let balance: Int
    let chargedCoins: Int
    let walletRevision: Int64
    let purchased: Bool
}
