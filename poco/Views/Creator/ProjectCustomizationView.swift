import SwiftUI
import UIKit

struct ProjectCustomizationView: View {
    @Environment(PocoStore.self) private var store
    let project: Project

    @State private var badgeSlotSelection: BadgeSlotSelection?
    @State private var selectedBadge: StarStoreItem?
    @State private var isUpdating = false
    @State private var errorMessage: String?

    private var decoration: ProjectDecoration {
        store.projectDecoration(for: project.id)
    }

    private var ownedBackgrounds: [StarStoreItem] {
        store.starStoreItems.filter {
            $0.kind == .projectBackground && store.ownedStarItemIDs.contains($0.id)
        }
    }

    private var equippedBadgesBySlot: [Int: StarStoreItem] {
        Dictionary(
            uniqueKeysWithValues: (0..<3).compactMap { slot in
                store.starStoreItem(id: decoration.badgeItemID(slot: slot))
                    .map { (slot, $0) }
            }
        )
    }

    private var previewBackgroundItem: StarStoreItem? {
        store.starStoreItem(id: decoration.backgroundItemID)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                preview
                backgroundSection
                badgeSection
            }
            .padding(PocoTheme.pagePadding)
            .padding(.bottom, 24)
        }
        .background(PocoTheme.groupedBackground)
        .navigationTitle("ハコを飾る")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                StarCoinBadge(balance: store.starCoinBalance)
            }
        }
        .task(id: project.id) {
            async let rewards: Void = store.loadMemberRewards()
            async let catalog: Void = store.loadStarStore()
            _ = await (rewards, catalog)
            await store.loadProjectDecoration(projectID: project.id)
        }
        .sheet(item: $badgeSlotSelection) { selection in
            NavigationStack {
                ProjectBadgePickerView(
                    projectID: project.id,
                    slot: selection.slot,
                    selectedItemID: decoration.badgeItemID(slot: selection.slot),
                    usedItemIDs: Set(decoration.badgeItemIDsBySlot.values),
                    onFinished: { badgeSlotSelection = nil }
                )
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedBadge) { item in
            BadgeDetailSheet(item: item, ownershipLabel: "作品に飾っています")
        }
        .alert(
            "変更できませんでした",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Text("プレビュー")
                    .pocoFont(.headline, weight: .bold)
                Spacer()
                if isUpdating {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("装飾を更新中")
                }
            }

            ZStack {
                ProjectBackgroundArtwork(item: previewBackgroundItem)
                    .clipShape(
                        RoundedRectangle(cornerRadius: PocoTheme.cornerLarge, style: .continuous)
                    )

                VStack(spacing: 14) {
                    Text(project.title)
                        .pocoFont(.headline, weight: .bold)
                        .lineLimit(1)

                    HStack(spacing: 9) {
                        sampleBubble(color: .pink, width: 92)
                        sampleBubble(color: .mint, width: 72)
                        sampleBubble(color: .blue, width: 84)
                    }

                    ProjectBadgeCaseView(
                        itemsBySlot: equippedBadgesBySlot,
                        onSelect: { selectedBadge = $0 }
                    )
                }
                .padding(18)
            }
            .frame(height: 190)
            .overlay {
                RoundedRectangle(cornerRadius: PocoTheme.cornerLarge, style: .continuous)
                    .stroke(.white.opacity(0.85), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.05), radius: 12, y: 5)
        }
    }

    private func sampleBubble(color: BubbleColor, width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(PocoTheme.bubble(color))
            .frame(width: width, height: 46)
            .overlay(alignment: .topLeading) {
                Capsule()
                    .fill(.white.opacity(0.7))
                    .frame(width: 22, height: 6)
                    .padding(8)
            }
            .rotationEffect(.degrees(Double(width.truncatingRemainder(dividingBy: 5)) - 2))
            .accessibilityHidden(true)
    }

    private var backgroundSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("背景")
                .pocoFont(.headline, weight: .bold)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    backgroundChoice(item: nil, title: "白")
                    ForEach(ownedBackgrounds) { item in
                        backgroundChoice(item: item, title: item.title)
                    }
                }
                .padding(.vertical, 3)
            }
        }
    }

    private func backgroundChoice(item: StarStoreItem?, title: String) -> some View {
        let isSelected = decoration.backgroundItemID == item?.id
        return Button {
            updateBackground(item?.id)
        } label: {
            VStack(spacing: 7) {
                ProjectBackgroundArtwork(item: item)
                    .frame(width: 76, height: 62)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(
                                isSelected ? PocoTheme.primary : PocoTheme.separator.opacity(0.45),
                                lineWidth: isSelected ? 3 : 1
                            )
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.white, PocoTheme.primary)
                                .padding(5)
                        }
                    }
                Text(title)
                    .pocoFont(.caption2, weight: isSelected ? .bold : .regular)
                    .foregroundStyle(isSelected ? PocoTheme.primary : .primary)
                    .lineLimit(1)
            }
            .frame(width: 86)
        }
        .buttonStyle(.plain)
        .disabled(isUpdating)
        .accessibilityLabel("背景、\(title)\(isSelected ? "、選択中" : "")")
    }

    private var badgeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("バッジケース")
                .pocoFont(.headline, weight: .bold)

            HStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { slot in
                    Button {
                        badgeSlotSelection = BadgeSlotSelection(slot: slot)
                    } label: {
                        VStack(spacing: 8) {
                            if let item = store.starStoreItem(
                                id: decoration.badgeItemID(slot: slot)
                            ) {
                                StarStoreArtworkView(item: item, size: 58)
                            } else {
                                Circle()
                                    .strokeBorder(
                                        PocoTheme.separator,
                                        style: StrokeStyle(lineWidth: 1, dash: [5])
                                    )
                                    .frame(width: 58, height: 58)
                                    .overlay {
                                        Image(systemName: "plus")
                                            .foregroundStyle(PocoTheme.tertiaryText)
                                    }
                            }
                            Text("枠 \(slot + 1)")
                                .pocoFont(.caption, weight: .medium)
                                .foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(PocoTheme.cardBackground, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                    .disabled(isUpdating)
                    .accessibilityLabel("バッジケースの\(slot + 1)枠目を変更")
                }
            }
        }
    }

    private func updateBackground(_ itemID: String?) {
        guard !isUpdating else { return }
        isUpdating = true
        Task {
            let result = await store.equipProjectBackground(
                projectID: project.id,
                itemID: itemID
            )
            isUpdating = false
            switch result {
            case .success:
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            case .failure(let error):
                errorMessage = error.userMessage
            }
        }
    }
}

private struct BadgeSlotSelection: Identifiable {
    let slot: Int
    var id: Int { slot }
}

private struct ProjectBadgePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PocoStore.self) private var store
    let projectID: UUID
    let slot: Int
    let selectedItemID: String?
    let usedItemIDs: Set<String>
    let onFinished: () -> Void

    @State private var selectedBadge: StarStoreItem?
    @State private var isUpdating = false
    @State private var errorMessage: String?

    private var ownedBadges: [StarStoreItem] {
        store.starStoreItems.filter {
            $0.kind == .profileBadge && store.ownedStarItemIDs.contains($0.id)
        }
    }

    var body: some View {
        List {
            Section {
                Button {
                    equip(nil)
                } label: {
                    Label("この枠を空にする", systemImage: "circle.dashed")
                }
                .disabled(selectedItemID == nil || isUpdating)
            }

            Section("購入済みのバッジ") {
                if ownedBadges.isEmpty {
                    Text("購入済みのバッジはありません。")
                        .foregroundStyle(PocoTheme.secondaryText)
                } else {
                    ForEach(ownedBadges) { item in
                        let isUsedElsewhere = usedItemIDs.contains(item.id)
                            && selectedItemID != item.id
                        HStack(spacing: 13) {
                            Button {
                                equip(item.id)
                            } label: {
                                HStack(spacing: 13) {
                                    StarStoreArtworkView(item: item, size: 44)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.title)
                                            .pocoFont(.subheadline, weight: .medium)
                                            .foregroundStyle(.primary)
                                        Text(isUsedElsewhere ? "別の枠に飾っています" : item.summary)
                                            .pocoFont(.caption)
                                            .foregroundStyle(PocoTheme.secondaryText)
                                            .lineLimit(2)
                                    }
                                    Spacer()
                                    if selectedItemID == item.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(PocoTheme.primary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(isUsedElsewhere || isUpdating)

                            Button {
                                selectedBadge = item
                            } label: {
                                Image(systemName: "info.circle")
                                    .foregroundStyle(PocoTheme.secondaryText)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(item.title)の説明")
                        }
                    }
                }
            }

            Section {
                NavigationLink {
                    StarStoreView()
                } label: {
                    Label("スターショップへ", systemImage: "bag.fill")
                }
            }
        }
        .navigationTitle("枠 \(slot + 1)のバッジ")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("閉じる") {
                    dismiss()
                    onFinished()
                }
            }
        }
        .overlay {
            if isUpdating {
                ProgressView()
                    .padding(16)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .sheet(item: $selectedBadge) { item in
            BadgeDetailSheet(item: item, ownershipLabel: "購入済み")
        }
        .alert(
            "変更できませんでした",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func equip(_ itemID: String?) {
        guard !isUpdating else { return }
        isUpdating = true
        Task {
            let result = await store.equipProjectBadge(
                projectID: projectID,
                slot: slot,
                itemID: itemID
            )
            isUpdating = false
            switch result {
            case .success:
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                dismiss()
                onFinished()
            case .failure(let error):
                errorMessage = error.userMessage
            }
        }
    }
}
