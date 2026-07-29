import SwiftUI

struct ProjectDecorationBackground: View {
    @Environment(PocoStore.self) private var store
    let projectID: UUID

    var body: some View {
        backgroundColor
            .overlay {
                Color.white.opacity(backgroundItem == nil ? 0 : 0.16)
            }
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }

    private var backgroundItem: StarStoreItem? {
        let decoration = store.projectDecoration(for: projectID)
        return store.starStoreItem(id: decoration.backgroundItemID)
    }

    private var backgroundColor: Color {
        backgroundItem?.decorationColor ?? PocoTheme.background
    }
}

struct ProjectBadgeCaseView: View {
    private let itemsBySlot: [Int: StarStoreItem]
    private let showsEmptySlots: Bool
    private let onSelect: ((StarStoreItem) -> Void)?

    init(
        items: [StarStoreItem],
        showsEmptySlots: Bool = false,
        onSelect: ((StarStoreItem) -> Void)? = nil
    ) {
        itemsBySlot = Dictionary(
            uniqueKeysWithValues: items.prefix(3).enumerated().map { ($0.offset, $0.element) }
        )
        self.showsEmptySlots = showsEmptySlots
        self.onSelect = onSelect
    }

    init(
        itemsBySlot: [Int: StarStoreItem],
        showsEmptySlots: Bool = true,
        onSelect: ((StarStoreItem) -> Void)? = nil
    ) {
        self.itemsBySlot = itemsBySlot.filter { (0..<3).contains($0.key) }
        self.showsEmptySlots = showsEmptySlots
        self.onSelect = onSelect
    }

    var body: some View {
        HStack(spacing: 9) {
            ForEach(0..<slotCount, id: \.self) { index in
                if let item = itemsBySlot[index] {
                    Button {
                        onSelect?(item)
                    } label: {
                        StarStoreArtworkView(item: item, size: 42)
                    }
                    .buttonStyle(.plain)
                    .disabled(onSelect == nil)
                    .accessibilityLabel(item.title)
                    .accessibilityHint("バッジの説明を表示します")
                } else {
                    Circle()
                        .strokeBorder(PocoTheme.separator.opacity(0.65), style: StrokeStyle(lineWidth: 1, dash: [4]))
                        .frame(width: 42, height: 42)
                        .overlay {
                            Image(systemName: "plus")
                                .pocoFont(.caption, weight: .medium)
                                .foregroundStyle(PocoTheme.tertiaryText)
                        }
                        .accessibilityHidden(true)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.thinMaterial, in: Capsule())
        .accessibilityElement(children: .contain)
        .accessibilityLabel("作品のバッジケース")
    }

    private var slotCount: Int {
        showsEmptySlots ? 3 : min(itemsBySlot.count, 3)
    }
}

struct BadgeDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let item: StarStoreItem
    var ownershipLabel: String?

    var body: some View {
        VStack(spacing: 20) {
            Capsule()
                .fill(PocoTheme.separator.opacity(0.55))
                .frame(width: 38, height: 5)

            StarStoreArtworkView(item: item, size: 96)

            VStack(spacing: 8) {
                Text(item.title)
                    .pocoFont(.title2, weight: .bold)
                    .multilineTextAlignment(.center)
                Text(item.summary)
                    .pocoFont(.body)
                    .foregroundStyle(PocoTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let ownershipLabel {
                Text(ownershipLabel)
                    .pocoFont(.caption, weight: .bold)
                    .foregroundStyle(PocoTheme.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(PocoTheme.primary.opacity(0.1), in: Capsule())
            }

            Button("閉じる") {
                dismiss()
            }
            .buttonStyle(PocoSecondaryButtonStyle())
        }
        .padding(PocoTheme.pagePadding)
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
        .accessibilityElement(children: .contain)
    }
}
