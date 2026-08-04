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

    var artworkAssetName: String? {
        switch id {
        case "background_sakura": "ProjectBackgroundSakura"
        case "background_lemon": "ProjectBackgroundLemon"
        case "background_sky": "ProjectBackgroundSky"
        case "background_mint": "ProjectBackgroundMint"
        case "background_lavender": "ProjectBackgroundLavender"
        case "badge_first_light": "BadgeFirstLight"
        case "badge_word_bouquet": "BadgeWordBouquet"
        case "badge_poco_heart": "PocoCreatorHeartReceived"
        default: imageAssetName
        }
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
    let ownedQuantity: Int
    let purchased: Bool
}

nonisolated struct BadgeGiftResult: Equatable, Sendable {
    let itemID: String
    let senderQuantity: Int
    let recipientQuantity: Int
    let gifted: Bool
}

nonisolated struct ProjectSlotStatus: Equatable, Sendable {
    let freeProjectLimit: Int
    let extraSlots: Int
    let nextSlotNumber: Int?
    let nextSlotCost: Int?
    let balance: Int
    let walletRevision: Int64

    static let base = Self(
        freeProjectLimit: 3,
        extraSlots: 0,
        nextSlotNumber: 4,
        nextSlotCost: 200,
        balance: 0,
        walletRevision: 0
    )
}

nonisolated struct ProjectSlotRedemptionResult: Equatable, Sendable {
    let status: ProjectSlotStatus
    let chargedCoins: Int
    let redeemed: Bool
}
