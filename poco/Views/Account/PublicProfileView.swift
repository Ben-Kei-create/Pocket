import SwiftUI

struct PublicProfileView: View {
    @Environment(PocoStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let creator: Creator
    @State private var showsBlockConfirmation = false
    @State private var isBlocking = false

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
    }

    private var profileContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    ProfileAvatarView(creator: creator, size: 104)

                    VStack(spacing: 5) {
                        HStack(spacing: 6) {
                            Text(creator.name)
                                .font(.title2.bold())
                            if creator.id == store.currentUserID {
                                Text("あなた")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(PocoTheme.primary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(PocoTheme.primary.opacity(0.12), in: Capsule())
                            }
                        }

                        Text("Poco 公開プロフィール")
                            .font(.subheadline)
                            .foregroundStyle(PocoTheme.secondaryText)
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
                        .font(.headline)

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
                .font(.headline.monospacedDigit())
                .foregroundStyle(PocoTheme.primary)
            Text(title)
                .font(.caption)
                .foregroundStyle(PocoTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}
