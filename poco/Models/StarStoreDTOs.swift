import Foundation

nonisolated struct StarStoreItemDTO: Decodable, Sendable {
    let id: String
    let itemType: String
    let title: String
    let summary: String
    let priceCoins: Int
    let assetName: String?
    let appearanceValue: String?
    let requiresPro: Bool
    let sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case id, title, summary
        case itemType = "item_type"
        case priceCoins = "price_coins"
        case assetName = "asset_name"
        case appearanceValue = "appearance_value"
        case requiresPro = "requires_pro"
        case sortOrder = "sort_order"
    }

    var domainModel: StarStoreItem? {
        guard let kind = StarStoreItemKind(rawValue: itemType) else { return nil }
        return StarStoreItem(
            id: id,
            kind: kind,
            title: title,
            summary: summary,
            priceCoins: priceCoins,
            assetName: assetName,
            appearanceValue: appearanceValue,
            requiresPro: requiresPro,
            sortOrder: sortOrder
        )
    }
}

nonisolated struct OwnedStarItemDTO: Decodable, Sendable {
    let itemID: String

    enum CodingKeys: String, CodingKey {
        case itemID = "item_id"
    }
}

nonisolated struct ProjectCustomizationDTO: Decodable, Sendable {
    let backgroundItemID: String

    enum CodingKeys: String, CodingKey {
        case backgroundItemID = "background_item_id"
    }
}

nonisolated struct ProjectBadgeSlotDTO: Decodable, Sendable {
    let slotIndex: Int
    let itemID: String

    enum CodingKeys: String, CodingKey {
        case slotIndex = "slot_index"
        case itemID = "item_id"
    }
}

nonisolated struct StarStorePurchaseResultDTO: Decodable, Sendable {
    let itemID: String
    let starCoinBalance: Int
    let chargedCoins: Int
    let walletRevision: Int64
    let purchased: Bool

    enum CodingKeys: String, CodingKey {
        case itemID = "item_id"
        case starCoinBalance = "star_coin_balance"
        case chargedCoins = "charged_coins"
        case walletRevision = "wallet_revision"
        case purchased
    }

    var domainModel: StarStorePurchaseResult {
        StarStorePurchaseResult(
            itemID: itemID,
            balance: starCoinBalance,
            chargedCoins: chargedCoins,
            walletRevision: walletRevision,
            purchased: purchased
        )
    }
}

nonisolated struct PurchaseStarItemParameters: Encodable, Sendable {
    let itemID: String
    let requestID: UUID

    enum CodingKeys: String, CodingKey {
        case itemID = "p_item_id"
        case requestID = "p_request_id"
    }
}

nonisolated struct EquipProjectBackgroundParameters: Encodable, Sendable {
    let projectID: UUID
    let itemID: String?

    enum CodingKeys: String, CodingKey {
        case projectID = "p_project_id"
        case itemID = "p_item_id"
    }
}

nonisolated struct EquipProjectBadgeParameters: Encodable, Sendable {
    let projectID: UUID
    let slotIndex: Int
    let itemID: String?

    enum CodingKeys: String, CodingKey {
        case projectID = "p_project_id"
        case slotIndex = "p_slot_index"
        case itemID = "p_item_id"
    }
}
