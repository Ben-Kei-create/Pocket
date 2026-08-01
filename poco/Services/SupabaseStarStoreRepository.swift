import Foundation
import Supabase

final class SupabaseStarStoreRepository: StarStoreRepository, Sendable {
    private let client: SupabaseClient
    private let currentUserProvider: any CurrentUserProvider

    init(client: SupabaseClient, currentUserProvider: any CurrentUserProvider) {
        self.client = client
        self.currentUserProvider = currentUserProvider
    }

    nonisolated func fetchCatalog() async throws -> [StarStoreItem] {
        do {
            let rows: [StarStoreItemDTO] = try await client
                .from("star_sku_catalog")
                .select(
                    "id,item_type,title,summary,price_coins,asset_name,"
                        + "appearance_value,requires_pro,sort_order"
                )
                .eq("is_active", value: true)
                .order("sort_order", ascending: true)
                .execute()
                .value
            return rows.compactMap(\.domainModel)
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }

    nonisolated func fetchOwnedItemIDs() async throws -> Set<String> {
        guard await currentUserProvider.accountStatus() == .registered else { return [] }
        do {
            let rows: [OwnedStarItemDTO] = try await client
                .from("user_owned_items")
                .select("item_id")
                .execute()
                .value
            return Set(rows.map(\.itemID))
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }

    nonisolated func fetchProjectDecoration(projectID: UUID) async throws -> ProjectDecoration {
        do {
            async let customizationRequest: [ProjectCustomizationDTO] = client
                .from("project_customizations")
                .select("background_item_id")
                .eq("project_id", value: projectID)
                .limit(1)
                .execute()
                .value
            async let badgeRequest: [ProjectBadgeSlotDTO] = client
                .from("project_badge_slots")
                .select("slot_index,item_id")
                .eq("project_id", value: projectID)
                .order("slot_index", ascending: true)
                .execute()
                .value
            let (customizationRows, badgeRows) = try await (
                customizationRequest,
                badgeRequest
            )
            return ProjectDecoration(
                backgroundItemID: customizationRows.first?.backgroundItemID,
                badgeItemIDsBySlot: Dictionary(
                    uniqueKeysWithValues: badgeRows.map { ($0.slotIndex, $0.itemID) }
                )
            )
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }

    nonisolated func purchaseItem(
        id: String,
        requestID: UUID
    ) async throws -> StarStorePurchaseResult {
        guard await currentUserProvider.accountStatus() == .registered else {
            throw AppError.unauthorized
        }
        do {
            let rows: [StarStorePurchaseResultDTO] = try await client
                .rpc(
                    "purchase_star_item",
                    params: PurchaseStarItemParameters(itemID: id, requestID: requestID)
                )
                .execute()
                .value
            guard let result = rows.first else { throw AppError.decoding }
            return result.domainModel
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }

    nonisolated func fetchProjectSlotStatus() async throws -> ProjectSlotStatus {
        guard await currentUserProvider.accountStatus() == .registered else {
            throw AppError.unauthorized
        }
        do {
            let rows: [ProjectSlotStatusDTO] = try await client
                .rpc("get_project_slot_status")
                .execute()
                .value
            guard let status = rows.first else { throw AppError.decoding }
            return status.domainModel
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }

    nonisolated func redeemProjectSlot(
        requestID: UUID
    ) async throws -> ProjectSlotRedemptionResult {
        guard await currentUserProvider.accountStatus() == .registered else {
            throw AppError.unauthorized
        }
        do {
            let rows: [ProjectSlotRedemptionDTO] = try await client
                .rpc(
                    "redeem_project_slot",
                    params: RedeemProjectSlotParameters(requestID: requestID)
                )
                .execute()
                .value
            guard let result = rows.first else { throw AppError.decoding }
            return result.domainModel
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }

    nonisolated func equipProjectBackground(
        projectID: UUID,
        itemID: String?
    ) async throws {
        do {
            try await client
                .rpc(
                    "equip_project_background",
                    params: EquipProjectBackgroundParameters(
                        projectID: projectID,
                        itemID: itemID
                    )
                )
                .execute()
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }

    nonisolated func equipProjectBadge(
        projectID: UUID,
        slot: Int,
        itemID: String?
    ) async throws {
        do {
            try await client
                .rpc(
                    "equip_project_badge",
                    params: EquipProjectBadgeParameters(
                        projectID: projectID,
                        slotIndex: slot,
                        itemID: itemID
                    )
                )
                .execute()
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }
}
