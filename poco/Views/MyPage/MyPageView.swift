import SwiftUI

struct MyPageView: View {
    @Environment(PocoStore.self) private var store
    @AppStorage("poco.hasCompletedWelcome") private var hasCompletedWelcome = true
    @State private var showsMembership = false
    @State private var showsRegistration = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 16) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 58))
                            .foregroundStyle(PocoTheme.bubble(.lavender))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(store.currentDisplayName)
                                .font(.headline)
                            Text(accountLabel)
                                .font(.caption)
                                .foregroundStyle(PocoTheme.secondaryText)
                        }
                        Spacer()
                        if store.isPocoMember {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(PocoTheme.primary)
                                .accessibilityLabel("Pocoメンバー")
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
                                    .font(.headline)
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
                            Label("Pocoメンバーになる", systemImage: "heart.circle.fill")
                                .font(.headline)
                                .foregroundStyle(PocoTheme.primary)
                        }
                    } footer: {
                        Text("共感のフキダシ、受け取ったいいね、広告なしを利用できます。")
                    }
                }

                Section("Poco") {
                    Label("送った感想", systemImage: "bubble.left")
                    Label("いいねしたフキダシ", systemImage: "heart")
                    Label("通知", systemImage: "bell")
                }

                Section {
                    Button("Welcomeをもう一度見る") {
                        hasCompletedWelcome = false
                    }
                    .foregroundStyle(PocoTheme.primary)
                }

                if store.canCreateProjects {
                    Section {
                        Button("ログアウト", role: .destructive) {
                            Task { await store.signOut() }
                        }
                    } footer: {
                        Text("ログアウト後も、閲覧と新しい感想の投稿はゲストとして利用できます。")
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
                RegistrationGateView()
            }
        }
    }

    private var accountLabel: String {
        if store.isPocoMember { return "Pocoメンバー" }
        return store.canCreateProjects ? "登録ユーザー" : "Pocoゲスト"
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
                .font(.headline.monospacedDigit())
                .foregroundStyle(PocoTheme.primary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title)が受け取ったいいね、\(value)件")
    }
}
