import SwiftUI

struct PocoSettingsView: View {
    @Environment(PocoStore.self) private var store
    @AppStorage("poco.settings.reactionNotifications") private var reactionNotifications = true
    @AppStorage("poco.settings.creatorHeartNotifications") private var creatorHeartNotifications = true
    @AppStorage("poco.hasCompletedWelcome") private var hasCompletedWelcome = true
    @State private var showsProfileEdit = false
    @State private var showsMembership = false
    @State private var showsAccountDeletion = false

    var body: some View {
        List {
            if store.canCreateProjects {
                Section("アカウント") {
                    Button {
                        showsProfileEdit = true
                    } label: {
                        Label("プロフィールを編集", systemImage: "person.crop.circle")
                    }
                    .foregroundStyle(.primary)

                    Button {
                        showsMembership = true
                    } label: {
                        HStack {
                            Label("メンバーシップ", systemImage: "heart.circle")
                            Spacer()
                            Text(store.role.title)
                                .pocoFont(.subheadline)
                                .foregroundStyle(PocoTheme.secondaryText)
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }

            Section {
                Toggle(isOn: $reactionNotifications) {
                    Label("いいね・スタンプ", systemImage: "heart")
                }
                Toggle(isOn: $creatorHeartNotifications) {
                    Label("作者からの❤️", systemImage: "heart.circle.fill")
                }
            } header: {
                Text("通知")
            }

            Section("Pocoについて") {
                if store.canCreateProjects {
                    Button {
                        store.replayOnboarding()
                    } label: {
                        Label(
                            store.isPocoMember
                                ? "Proの使い方をもう一度見る"
                                : "Pocoの使い方をもう一度見る",
                            systemImage: "questionmark.circle"
                        )
                    }
                    .foregroundStyle(.primary)
                }

                Button {
                    hasCompletedWelcome = false
                } label: {
                    Label("Welcomeをもう一度見る", systemImage: "hand.wave")
                }
                .foregroundStyle(.primary)

                HStack {
                    Label("バージョン", systemImage: "info.circle")
                    Spacer()
                    Text(appVersion)
                        .foregroundStyle(PocoTheme.secondaryText)
                }
                .accessibilityElement(children: .combine)
            }

            if store.canCreateProjects {
                Section {
                    Button("ログアウト", role: .destructive) {
                        Task { await store.signOut() }
                    }
                } footer: {
                    Text("ログアウト後も、閲覧と感想投稿はゲストとして利用できます。")
                }
            }

            if store.accountStatus == .registered {
                Section {
                    Button("アカウントを削除", role: .destructive) {
                        showsAccountDeletion = true
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("設定")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showsProfileEdit) {
            ProfileEditView()
        }
        .sheet(isPresented: $showsMembership) {
            PocoMembershipView()
        }
        .sheet(isPresented: $showsAccountDeletion) {
            AccountDeletionView()
        }
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        return [version, build.map { "(\($0))" }]
            .compactMap { $0 }
            .joined(separator: " ")
    }
}
