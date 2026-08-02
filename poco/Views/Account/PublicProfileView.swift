import SwiftUI
import UIKit

struct PublicProfileView: View {
    @Environment(PocoStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let creator: Creator
    @State private var loadedCreator: Creator?
    @State private var showsBlockConfirmation = false
    @State private var showsBadgeGift = false
    @State private var isBlocking = false

    init(creator: Creator) {
        self.creator = creator
        _loadedCreator = State(initialValue: nil)
    }

    private var displayedCreator: Creator { loadedCreator ?? creator }

    private var publishedProjects: [Project] {
        store.projects
            .filter { $0.creator.id == creator.id }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var totalFeedbackCount: Int {
        publishedProjects.reduce(0) { $0 + $1.feedbackCount }
    }

    var body: some View {
        Group {
            if store.blockedProfileIDs.contains(creator.id) {
                ContentUnavailableView(
                    "ブロック中のユーザーです",
                    systemImage: "person.crop.circle.badge.xmark",
                    description: Text("このユーザーのフキダシは表示されません。")
                )
            } else {
                profileContent
            }
        }
        .background(PocoTheme.groupedBackground)
        .navigationTitle("プロフィール")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if creator.id != store.currentUserID,
               !store.blockedProfileIDs.contains(creator.id) {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        if store.accountStatus == .registered {
                            Button {
                                showsBadgeGift = true
                            } label: {
                                Label("バッジを贈る", systemImage: "gift.fill")
                            }
                        }
                        Button(role: .destructive) {
                            showsBlockConfirmation = true
                        } label: {
                            Label("このユーザーをブロック", systemImage: "person.crop.circle.badge.xmark")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .disabled(isBlocking)
                    .accessibilityLabel("プロフィールのその他の操作")
                }
            }
        }
        .confirmationDialog(
            "このユーザーをブロックしますか？",
            isPresented: $showsBlockConfirmation,
            titleVisibility: .visible
        ) {
            Button("ブロックする", role: .destructive) {
                isBlocking = true
                Task {
                    let result = await store.block(creator)
                    isBlocking = false
                    if case .success = result { dismiss() }
                }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("このユーザーの公開フキダシが表示されなくなります。相手には通知されません。")
        }
        .sheet(isPresented: $showsBadgeGift) {
            BadgeGiftSheet(recipient: displayedCreator)
        }
        .task(id: creator.id) {
            loadedCreator = await store.loadPublicProfile(id: creator.id)
        }
    }

    private var profileContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    ProfileAvatarView(creator: displayedCreator, size: 104)

                    VStack(spacing: 5) {
                        HStack(spacing: 6) {
                            Text(displayedCreator.name)
                                .pocoFont(.title2, weight: .bold)
                            if creator.id == store.currentUserID {
                                Text("あなた")
                                    .pocoFont(.caption2, weight: .bold)
                                    .foregroundStyle(PocoTheme.primary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(PocoTheme.primary.opacity(0.12), in: Capsule())
                            }
                        }

                        if let handle = displayedCreator.handle {
                            Text("@\(handle)")
                                .pocoFont(.subheadline, weight: .medium)
                                .foregroundStyle(PocoTheme.primary)
                                .accessibilityLabel("クリエイターID、\(handle)")
                        }

                    }

                    if !displayedCreator.profileLinks.isEmpty {
                        ProfileSocialLinksView(links: displayedCreator.profileLinks)
                            .frame(maxWidth: .infinity)
                    }

                    HStack(spacing: 0) {
                        profileMetric(
                            value: publishedProjects.count,
                            title: "公開作品",
                            symbol: "books.vertical"
                        )
                        Divider().frame(height: 42)
                        profileMetric(
                            value: totalFeedbackCount,
                            title: "届いた感想",
                            symbol: "bubble.left"
                        )
                    }
                    .padding(.vertical, 14)
                    .pocoCard()
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text("公開している作品")
                        .pocoFont(.headline, weight: .medium)

                    if publishedProjects.isEmpty {
                        ContentUnavailableView(
                            "公開作品はまだありません",
                            systemImage: "books.vertical"
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    } else {
                        ForEach(publishedProjects) { project in
                            NavigationLink {
                                ProjectDetailView(projectID: project.id)
                            } label: {
                                ProjectCard(project: project)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(PocoTheme.pagePadding)
            .padding(.bottom, 20)
        }
    }

    private func profileMetric(value: Int, title: String, symbol: String) -> some View {
        VStack(spacing: 4) {
            Label(value.formatted(), systemImage: symbol)
                .pocoFont(.headline).monospacedDigit()
                .foregroundStyle(PocoTheme.primary)
            Text(title)
                .pocoFont(.caption)
                .foregroundStyle(PocoTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

private struct BadgeGiftSheet: View {
    @Environment(PocoStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let recipient: Creator

    @State private var pendingItem: StarStoreItem?
    @State private var giftingItemID: String?
    @State private var noticeMessage: String?

    private var ownedBadges: [StarStoreItem] {
        store.starStoreItems.filter {
            $0.kind == .profileBadge && store.ownedQuantity(for: $0.id) > 0
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if ownedBadges.isEmpty {
                    ContentUnavailableView(
                        "贈れるバッジがありません",
                        systemImage: "gift",
                        description: Text("スターショップでバッジを購入できます。")
                    )
                } else {
                    Section {
                        ForEach(ownedBadges) { item in
                            HStack(spacing: 14) {
                                StarStoreArtworkView(item: item, size: 52)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.title)
                                        .pocoFont(.subheadline, weight: .bold)
                                    Text("所持 ×\(store.ownedQuantity(for: item.id))")
                                        .pocoFont(.caption)
                                        .foregroundStyle(PocoTheme.secondaryText)
                                }
                                Spacer()
                                Button("贈る") { pendingItem = item }
                                    .buttonStyle(.borderedProminent)
                                    .tint(PocoTheme.primary)
                                    .disabled(giftingItemID != nil)
                            }
                            .padding(.vertical, 5)
                        }
                    } footer: {
                        Text("作品に飾っている分は贈れません。贈ったバッジは取り消せません。")
                    }
                }
            }
            .navigationTitle("\(recipient.name)さんへ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .task { await store.loadStarStore(reportsErrors: false) }
            .confirmationDialog(
                "バッジを贈りますか？",
                isPresented: Binding(
                    get: { pendingItem != nil },
                    set: { if !$0 { pendingItem = nil } }
                ),
                titleVisibility: .visible,
                presenting: pendingItem
            ) { item in
                Button("「\(item.title)」を1個贈る") { gift(item) }
                Button("キャンセル", role: .cancel) {}
            } message: { _ in
                Text("贈ったあとは元に戻せません。")
            }
            .alert(
                "バッジ",
                isPresented: Binding(
                    get: { noticeMessage != nil },
                    set: { if !$0 { noticeMessage = nil } }
                )
            ) {
                Button("OK") {
                    if noticeMessage?.contains("贈りました") == true { dismiss() }
                }
            } message: {
                Text(noticeMessage ?? "")
            }
        }
    }

    private func gift(_ item: StarStoreItem) {
        pendingItem = nil
        giftingItemID = item.id
        Task {
            let result = await store.giftBadge(item, to: recipient)
            giftingItemID = nil
            switch result {
            case .success(let gift):
                if gift.gifted {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    noticeMessage = "\(recipient.name)さんへ「\(item.title)」を贈りました。"
                }
            case .failure(let error):
                noticeMessage = error.userMessage
            }
        }
    }
}
