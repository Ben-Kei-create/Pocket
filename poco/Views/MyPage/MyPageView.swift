import SwiftUI

struct MyPageView: View {
    @Environment(PocoStore.self) private var store
    @State private var showsMembership = false
    @State private var showsRegistration = false
    @State private var showsProfileEdit = false
    @State private var showsNotifications = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 16) {
                        ProfileAvatarView(
                            creator: store.currentProfile,
                            localImageData: store.currentAvatarImageData
                        )
                        VStack(alignment: .leading, spacing: 4) {
                            Text(store.currentDisplayName)
                                .pocoFont(.headline, weight: .medium)
                            if let handle = store.currentProfile?.handle {
                                Text("@\(handle)")
                                    .pocoFont(.caption, weight: .medium)
                                    .foregroundStyle(PocoTheme.primary)
                            }
                            Text(accountLabel)
                                .pocoFont(.caption)
                                .foregroundStyle(PocoTheme.secondaryText)
                        }
                        Spacer()
                        if store.canCreateProjects {
                            Button("編集") {
                                showsProfileEdit = true
                            }
                            .pocoFont(.subheadline, weight: .medium)
                            .foregroundStyle(PocoTheme.primary)
                            .accessibilityLabel("プロフィールを編集")
                        }
                        if store.isPocoMember {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(PocoTheme.primary)
                                .accessibilityLabel("Poco Pro")
                        }
                    }
                    .padding(.vertical, 6)
                }

                if store.isPocoMember {
                    Section("もらったいいね") {
                        LikeSummaryRow(
                            title: "自分の作品",
                            value: store.memberLikeSummary.projectLikes,
                            symbol: "books.vertical.fill"
                        )
                        LikeSummaryRow(
                            title: "自分の感想",
                            value: store.memberLikeSummary.feedbackLikes,
                            symbol: "bubble.left.fill"
                        )
                    }
                } else {
                    if !store.canCreateProjects {
                        Section {
                            Button {
                                showsRegistration = true
                            } label: {
                                Label("ユーザー登録する", systemImage: "person.badge.plus")
                                    .pocoFont(.headline, weight: .medium)
                                    .foregroundStyle(PocoTheme.primary)
                            }
                        } footer: {
                            Text("登録すると作品ページを作成できます。感想投稿はゲストのまま利用できます。")
                        }
                    }

                    Section {
                        Button {
                            showsMembership = true
                        } label: {
                            Label("Poco Proになる", systemImage: "heart.circle.fill")
                                .pocoFont(.headline, weight: .medium)
                                .foregroundStyle(PocoTheme.primary)
                        }
                    } footer: {
                        Text("共感のフキダシ、受け取ったいいね、広告なしを利用できます。")
                    }
                }

                if store.canCreateProjects {
                    Section("ごほうび") {
                        NavigationLink {
                            MemberRewardCenterView()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "gift.fill")
                                    .foregroundStyle(PocoTheme.primary)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("ログインボーナス")
                                    Text(
                                        store.memberRewardSnapshot.canClaimToday
                                            ? "今日のごほうびが届いています"
                                            : "\(store.memberRewardSnapshot.loginStreak)日つづいています"
                                    )
                                    .pocoFont(.caption)
                                    .foregroundStyle(PocoTheme.secondaryText)
                                }
                                Spacer()
                                if store.memberRewardSnapshot.canClaimToday {
                                    Text("NEW")
                                        .pocoFont(.caption2, weight: .bold)
                                        .foregroundStyle(PocoTheme.primary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(PocoTheme.bubble(.pink), in: Capsule())
                                }
                            }
                        }

                        NavigationLink {
                            AchievementStampsView()
                        } label: {
                            HStack {
                                Label("達成スタンプ", systemImage: "seal.fill")
                                Spacer()
                                Text(
                                    "\(store.memberRewardSnapshot.unlockedStamps.count)"
                                        + "/\(AchievementStamp.allCases.count)"
                                )
                                .pocoFont(.subheadline).monospacedDigit()
                                .foregroundStyle(PocoTheme.secondaryText)
                            }
                        }
                    }
                }

                Section("Poco") {
                    NavigationLink {
                        FeedbackActivityView(kind: .sent)
                    } label: {
                        Label("送った感想", systemImage: "bubble.left")
                    }

                    NavigationLink {
                        FeedbackActivityView(kind: .liked)
                    } label: {
                        Label("いいねしたフキダシ", systemImage: "heart")
                    }

                    Button {
                        showsNotifications = true
                    } label: {
                        HStack {
                            Label("届いたことば", systemImage: "bell")
                            Spacer()
                            if store.unreadNotificationCount > 0 {
                                Text(store.unreadNotificationCount.formatted())
                                    .pocoFont(.caption2, weight: .bold)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(PocoTheme.primary, in: Capsule())
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                    .accessibilityLabel(
                        store.unreadNotificationCount > 0
                            ? "届いたことば、未読\(store.unreadNotificationCount)件"
                            : "届いたことば"
                    )

                    NavigationLink {
                        PocoSettingsView()
                    } label: {
                        Label("設定", systemImage: "gearshape")
                    }
                }

                if store.backendMode == .mock && store.isPocoMember {
                    Section("開発用") {
                        Button("ゲスト表示に戻す", role: .destructive) {
                            store.resetPreviewMembership()
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("マイページ")
            .sheet(isPresented: $showsMembership) {
                PocoMembershipView()
            }
            .sheet(isPresented: $showsRegistration) {
                RegistrationGateView(context: .account)
            }
            .sheet(isPresented: $showsProfileEdit) {
                ProfileEditView()
            }
            .sheet(isPresented: $showsNotifications) {
                NotificationCenterView()
            }
            .task(id: store.canCreateProjects) {
                if store.canCreateProjects {
                    await store.loadMemberRewards()
                }
            }
        }
    }

    private var accountLabel: String {
        store.role.title
    }
}

private struct LikeSummaryRow: View {
    let title: String
    let value: Int
    let symbol: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(PocoTheme.primary)
                .frame(width: 28)
            Text(title)
            Spacer()
            Label(value.formatted(), systemImage: "heart.fill")
                .pocoFont(.headline).monospacedDigit()
                .foregroundStyle(PocoTheme.primary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title)が受け取ったいいね、\(value)件")
    }
}
