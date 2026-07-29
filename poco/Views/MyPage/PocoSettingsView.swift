import SwiftUI

struct PocoSettingsView: View {
    @Environment(PocoStore.self) private var store
    @AppStorage("poco.settings.reactionNotifications") private var reactionNotifications = true
    @AppStorage("poco.settings.creatorHeartNotifications") private var creatorHeartNotifications = true
    @AppStorage("poco.settings.playfulMotion") private var playfulMotion = true
    @AppStorage("poco.hasCompletedWelcome") private var hasCompletedWelcome = true
    @State private var showsProfileEdit = false
    @State private var showsMembership = false

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
            } footer: {
                Text("プッシュ通知を利用するには、今後の通知許可も必要です。")
            }

            Section {
                Toggle(isOn: $playfulMotion) {
                    Label("ぷよん演出", systemImage: "sparkles")
                }
            } header: {
                Text("フキダシの体験")
            } footer: {
                Text("端末の『視差効果を減らす』が有効な場合は、この設定より優先されます。")
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
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        return [version, build.map { "(\($0))" }]
            .compactMap { $0 }
            .joined(separator: " ")
    }
}
