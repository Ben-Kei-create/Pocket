import SwiftUI
import UIKit

struct StarStoreView: View {
    @Environment(PocoStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var itemPendingPurchase: StarStoreItem?
    @State private var selectedBadge: StarStoreItem?
    @State private var purchasingItemID: String?
    @State private var noticeMessage: String?
    @State private var showsMembership = false

    private var backgrounds: [StarStoreItem] {
        store.starStoreItems.filter { $0.kind == .projectBackground }
    }

    private var badges: [StarStoreItem] {
        store.starStoreItems.filter { $0.kind == .profileBadge }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                header

                storeSection(
                    title: "ハコの背景",
                    subtitle: "作品ごとに、ことばが集まる場所の色を変えられます。",
                    items: backgrounds
                )

                storeSection(
                    title: "バッジ",
                    subtitle: "作品のバッジケースに3個まで飾れます。押すと意味を確認できます。",
                    items: badges
                )

                Text("購入した背景やバッジは、いつでも作品ごとに付け替えられます。")
                    .pocoFont(.caption)
                    .foregroundStyle(PocoTheme.tertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(PocoTheme.pagePadding)
            .padding(.bottom, 24)
        }
        .background(PocoTheme.groupedBackground)
        .navigationTitle("スターショップ")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                StarCoinBadge(balance: store.starCoinBalance)
            }
        }
        .task {
            async let rewards: Void = store.loadMemberRewards()
            async let catalog: Void = store.loadStarStore()
            _ = await (rewards, catalog)
        }
        .sheet(item: $selectedBadge) { item in
            BadgeDetailSheet(
                item: item,
                ownershipLabel: store.ownedStarItemIDs.contains(item.id)
                    ? "購入済み"
                    : "⭐︎ \(item.priceCoins.formatted())"
            )
        }
        .sheet(isPresented: $showsMembership) {
            PocoMembershipView()
        }
        .confirmationDialog(
            "スターで購入しますか？",
            isPresented: Binding(
                get: { itemPendingPurchase != nil },
                set: { if !$0 { itemPendingPurchase = nil } }
            ),
            titleVisibility: .visible,
            presenting: itemPendingPurchase
        ) { item in
            Button("⭐︎ \(item.priceCoins.formatted())で購入") {
                purchase(item)
            }
            Button("キャンセル", role: .cancel) {}
        } message: { item in
            Text("「\(item.title)」を購入します。購入後の取り消しはできません。")
        }
        .alert(
            "スターショップ",
            isPresented: Binding(
                get: { noticeMessage != nil },
                set: { if !$0 { noticeMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(noticeMessage ?? "")
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 38, weight: .semibold))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.yellow, PocoTheme.bubble(.yellow))
            VStack(alignment: .leading, spacing: 4) {
                Text("集めたスターで、Pocoを飾ろう")
                    .pocoFont(.title3, weight: .bold)
                Text("見た目が変わるだけで、表示順位や反応数には影響しません。")
                    .pocoFont(.caption)
                    .foregroundStyle(PocoTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pocoCard()
    }

    @ViewBuilder
    private func storeSection(
        title: String,
        subtitle: String,
        items: [StarStoreItem]
    ) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .pocoFont(.headline, weight: .bold)
                Text(subtitle)
                    .pocoFont(.caption)
                    .foregroundStyle(PocoTheme.secondaryText)
            }

            if store.starStoreLoadState == .loading && items.isEmpty {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("アイテムを読み込んでいます…")
                        .pocoFont(.subheadline)
                        .foregroundStyle(PocoTheme.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .pocoCard()
            } else if items.isEmpty {
                ContentUnavailableView(
                    "アイテムは準備中です",
                    systemImage: "sparkles"
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .pocoCard()
            } else {
                LazyVGrid(
                    columns: dynamicTypeSize.isAccessibilitySize
                        ? [GridItem(.flexible())]
                        : [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 12
                ) {
                    ForEach(items) { item in
                        StarStoreItemCard(
                            item: item,
                            isOwned: store.ownedStarItemIDs.contains(item.id),
                            isPurchasing: purchasingItemID == item.id,
                            canAfford: store.starCoinBalance >= item.priceCoins,
                            isProLocked: item.requiresPro && !store.isPocoMember,
                            onShowDetail: item.kind == .profileBadge
                                ? { selectedBadge = item }
                                : nil,
                            onPurchase: {
                                if store.starCoinBalance < item.priceCoins {
                                    noticeMessage = AppError.insufficientStarCoins.userMessage
                                } else if item.requiresPro && !store.isPocoMember {
                                    showsMembership = true
                                } else {
                                    itemPendingPurchase = item
                                }
                            }
                        )
                    }
                }
            }
        }
    }

    private func purchase(_ item: StarStoreItem) {
        guard purchasingItemID == nil else { return }
        itemPendingPurchase = nil
        purchasingItemID = item.id
        Task {
            let result = await store.purchaseStarStoreItem(item)
            purchasingItemID = nil
            switch result {
            case .success(let purchased):
                if purchased {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    noticeMessage = "「\(item.title)」を購入しました。"
                } else {
                    noticeMessage = "このアイテムは購入済みです。"
                }
            case .failure(let error):
                noticeMessage = error.userMessage
            }
        }
    }
}

private struct StarStoreItemCard: View {
    let item: StarStoreItem
    let isOwned: Bool
    let isPurchasing: Bool
    let canAfford: Bool
    let isProLocked: Bool
    let onShowDetail: (() -> Void)?
    let onPurchase: () -> Void

    var body: some View {
        VStack(spacing: 11) {
            Button {
                onShowDetail?()
            } label: {
                StarStoreArtworkView(item: item, size: 72)
            }
            .buttonStyle(.plain)
            .disabled(onShowDetail == nil)

            VStack(spacing: 4) {
                Text(item.title)
                    .pocoFont(.subheadline, weight: .bold)
                    .multilineTextAlignment(.center)
                Text(item.summary)
                    .pocoFont(.caption2)
                    .foregroundStyle(PocoTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if isOwned {
                Label("購入済み", systemImage: "checkmark.circle.fill")
                    .pocoFont(.caption, weight: .bold)
                    .foregroundStyle(PocoTheme.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(PocoTheme.primary.opacity(0.09), in: Capsule())
            } else {
                Button(action: onPurchase) {
                    if isPurchasing {
                        ProgressView()
                            .controlSize(.small)
                            .frame(maxWidth: .infinity)
                    } else if isProLocked {
                        Label("Pro限定", systemImage: "lock.fill")
                            .frame(maxWidth: .infinity)
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                            Text(item.priceCoins.formatted())
                                .monospacedDigit()
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.bordered)
                .tint(canAfford && !isProLocked ? PocoTheme.primary : PocoTheme.secondaryText)
                .disabled(isPurchasing)
                .accessibilityLabel(
                    isProLocked
                        ? "\(item.title)、Poco Pro限定"
                        : "\(item.title)をスター\(item.priceCoins)個で購入"
                )
                .accessibilityHint(
                    isProLocked
                        ? "Poco Proの案内を表示します"
                        : (canAfford ? "購入確認を表示します" : "スターが足りません")
                )
            }
        }
        .frame(maxWidth: .infinity, minHeight: 224, alignment: .top)
        .padding(14)
        .pocoCard(cornerRadius: PocoTheme.cornerSmall)
        .accessibilityElement(children: .contain)
    }
}
