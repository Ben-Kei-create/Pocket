import SwiftUI

struct MyPageView: View {
    @Environment(PocoStore.self) private var store
    @State private var showsMembership = false
    @State private var showsRegistration = false
    @State private var showsProfileEdit = false

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
                }
                }

                if store.canCreateProjects {
                    Section("ごほうび") {
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

                        NavigationLink {
                            StarStoreView()
                        } label: {
                            HStack {
                                Label("スターショップ", systemImage: "bag.fill")
                                Spacer()
                                StarCoinBadge(balance: store.starCoinBalance)
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

                    NavigationLink {
                        QAndAView()
                    } label: {
                        Label("Q&A", systemImage: "questionmark.bubble")
                    }

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
            .sheet(isPresented: $showsMembership) {
                PocoMembershipView()
            }
            .sheet(isPresented: $showsRegistration) {
                RegistrationGateView(context: .account)
            }
            .sheet(isPresented: $showsProfileEdit) {
                ProfileEditView()
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
