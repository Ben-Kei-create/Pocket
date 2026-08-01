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
    let backgroundItemID: String?

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

nonisolated struct ProjectSlotStatusDTO: Decodable, Sendable {
    let freeProjectLimit: Int
    let extraSlots: Int
    let nextSlotNumber: Int?
    let nextSlotCost: Int?
    let starCoinBalance: Int
    let walletRevision: Int64

    enum CodingKeys: String, CodingKey {
        case freeProjectLimit = "free_project_limit"
        case extraSlots = "extra_slots"
        case nextSlotNumber = "next_slot_number"
        case nextSlotCost = "next_slot_cost"
        case starCoinBalance = "star_coin_balance"
        case walletRevision = "wallet_revision"
    }

    var domainModel: ProjectSlotStatus {
        ProjectSlotStatus(
            freeProjectLimit: freeProjectLimit,
            extraSlots: extraSlots,
            nextSlotNumber: nextSlotNumber,
            nextSlotCost: nextSlotCost,
            balance: starCoinBalance,
            walletRevision: walletRevision
        )
    }
}

nonisolated struct ProjectSlotRedemptionDTO: Decodable, Sendable {
    let freeProjectLimit: Int
    let extraSlots: Int
    let nextSlotNumber: Int?
    let nextSlotCost: Int?
    let starCoinBalance: Int
    let chargedCoins: Int
    let walletRevision: Int64
    let redeemed: Bool

    enum CodingKeys: String, CodingKey {
        case freeProjectLimit = "free_project_limit"
        case extraSlots = "extra_slots"
        case nextSlotNumber = "next_slot_number"
        case nextSlotCost = "next_slot_cost"
        case starCoinBalance = "star_coin_balance"
        case chargedCoins = "charged_coins"
        case walletRevision = "wallet_revision"
        case redeemed
    }

    var domainModel: ProjectSlotRedemptionResult {
        ProjectSlotRedemptionResult(
            status: ProjectSlotStatus(
                freeProjectLimit: freeProjectLimit,
                extraSlots: extraSlots,
                nextSlotNumber: nextSlotNumber,
                nextSlotCost: nextSlotCost,
                balance: starCoinBalance,
                walletRevision: walletRevision
            ),
            chargedCoins: chargedCoins,
            redeemed: redeemed
        )
    }
}

nonisolated struct RedeemProjectSlotParameters: Encodable, Sendable {
    let requestID: UUID

    enum CodingKeys: String, CodingKey {
        case requestID = "p_request_id"
    }
}
