import SwiftUI

struct CreatorDashboardView: View {
    @Environment(PocoStore.self) private var store
    @State private var showsCreateProject = false
    @State private var showsRegistration = false
    @State private var showsProjectLimit = false
    @State private var editingProject: Project?
    @State private var projectPendingDeletion: Project?
    @State private var deletingProjectID: UUID?
    @State private var projectActionError: String?

    var body: some View {
        NavigationStack {
            Group {
                if store.canCreateProjects {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("ことばが集まる場所をつくろう")
                                    .pocoFont(.title2, weight: .bold)
                                Text("作品ごとのQRコードと感想を管理できます。")
                                    .pocoFont(.subheadline)
                                    .foregroundStyle(PocoTheme.secondaryText)
                            }
                            .padding(.top, 8)

                            Button {
                                if store.canCreateAnotherProject {
                                    showsCreateProject = true
                                } else {
                                    showsProjectLimit = true
                                }
                            } label: {
                                Label("新しい作品を作る", systemImage: "plus")
                            }
                            .buttonStyle(PocoPrimaryButtonStyle())
                            .padding(.vertical, 4)
                            .accessibilityHint(
                                store.canCreateAnotherProject
                                    ? "新しい作品の登録画面を開きます"
                                    : "現在のプランの作品数上限を確認します"
                            )

                            Text("\(store.currentUserProjects.count) / \(store.capabilities.maximumProjectCount)作品")
                                .pocoFont(.caption)
                                .foregroundStyle(PocoTheme.secondaryText)

                            Text("あなたの作品")
                                .pocoFont(.headline, weight: .medium)
                                .padding(.top, 8)

                            if store.currentUserProjects.isEmpty {
                                CreatorDashboardEmptyState()
                            } else {
                                ForEach(store.currentUserProjects) { project in
                                    CreatorProjectCard(
                                        project: project,
                                        isDeleting: deletingProjectID == project.id,
                                        onEdit: { editingProject = project },
                                        onDelete: { projectPendingDeletion = project }
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, PocoTheme.pagePadding)
                        .padding(.bottom, 24)
                    }
                    .background(PocoTheme.background)
                } else {
                    ContentUnavailableView {
                        Label("作品を作るには登録が必要です", systemImage: "person.crop.circle.badge.plus")
                    } description: {
                        Text("閲覧・感想投稿・いいねはゲストのまま利用できます。")
                    } actions: {
                        Button("ユーザー登録する") {
                            showsRegistration = true
                        }
                        .buttonStyle(PocoPrimaryButtonStyle())
                    }
                }
            }
            .navigationTitle("Create")
            .sheet(isPresented: $showsCreateProject) {
                CreateProjectView {
                    showsCreateProject = false
                    Task {
                        try? await Task.sleep(for: .milliseconds(250))
                        showsProjectLimit = true
                    }
                }
            }
            .sheet(isPresented: $showsRegistration) {
                RegistrationGateView()
            }
            .sheet(item: $editingProject) { project in
                CreateProjectView(project: project)
            }
            .sheet(isPresented: $showsProjectLimit) {
                ProjectLimitReachedView()
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .confirmationDialog(
                "「\(projectPendingDeletion?.title ?? "")」を削除しますか？",
                isPresented: Binding(
                    get: { projectPendingDeletion != nil },
                    set: { if !$0 { projectPendingDeletion = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("作品を非公開にする", role: .destructive) {
                    guard let project = projectPendingDeletion else { return }
                    projectPendingDeletion = nil
                    delete(project)
                }
                Button("キャンセル", role: .cancel) {
                    projectPendingDeletion = nil
                }
            } message: {
                Text("作品と感想はすぐに非公開になります。データと画像は監査・復旧のため30日間保持され、その後削除対象になります。")
            }
            .alert(
                "作品を削除できませんでした",
                isPresented: Binding(
                    get: { projectActionError != nil },
                    set: { if !$0 { projectActionError = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(projectActionError ?? "")
            }
        }
    }

    private func delete(_ project: Project) {
        deletingProjectID = project.id
        Task {
            let result = await store.deleteProject(project)
            deletingProjectID = nil
            if case .failure(let error) = result {
                projectActionError = error.userMessage
            }
        }
    }
}

private struct CreatorDashboardEmptyState: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "shippingbox")
                .pocoFont(.title2)
                .foregroundStyle(PocoTheme.primary)
                .frame(width: 58, height: 58)
                .background(PocoTheme.bubble(.yellow).opacity(0.55), in: Circle())
            Text("最初の作品を登録してみよう")
                .pocoFont(.headline, weight: .medium)
            Text("作品専用のQRコードと、ことばが集まる場所ができます。")
                .pocoFont(.caption)
                .foregroundStyle(PocoTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 20)
        .pocoCard()
        .accessibilityElement(children: .combine)
    }
}

private struct CreatorProjectCard: View {
    let project: Project
    let isDeleting: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 13) {
                ProjectArtworkThumbnail(project: project)
                    .frame(width: 66, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    ProjectRelationshipBadge(project: project, compact: true)
                    Text(project.title)
                        .pocoFont(.headline, weight: .medium)
                        .lineLimit(2)
                    Label("\(project.feedbackCount.formatted())件の感想", systemImage: "bubble.left")
                        .pocoFont(.caption)
                        .foregroundStyle(PocoTheme.secondaryText)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Menu {
                        Button(action: onEdit) {
                            Label("作品を編集", systemImage: "pencil")
                        }
                        Button(role: .destructive, action: onDelete) {
                            Label("作品を削除", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .pocoFont(.title3)
                            .foregroundStyle(PocoTheme.secondaryText)
                            .frame(width: 44, height: 32, alignment: .trailing)
                    }
                    .accessibilityLabel("\(project.title)の管理メニュー")

                    QRCodeImage(data: project.deepLinkURL.absoluteString)
                        .frame(width: 48, height: 48)
                        .accessibilityLabel("作品のQRコード")
                }
            }

            HStack(spacing: 8) {
                NavigationLink {
                    BubbleWallView(projectID: project.id)
                } label: {
                    Label("感想を見る", systemImage: "bubble.left.and.bubble.right")
                }
                .buttonStyle(.bordered)

                NavigationLink {
                    QRCodeView(project: project)
                } label: {
                    Label("QR", systemImage: "qrcode")
                }
                .buttonStyle(.bordered)

                ShareLink(item: project.deepLinkURL) {
                    Label("共有", systemImage: "link")
                }
                .buttonStyle(.bordered)
            }
            .pocoFont(.caption, weight: .medium)

            if isDeleting {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("作品を削除しています…")
                        .pocoFont(.caption)
                        .foregroundStyle(PocoTheme.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(16)
        .pocoCard()
        .disabled(isDeleting)
        .opacity(isDeleting ? 0.72 : 1)
    }
}
