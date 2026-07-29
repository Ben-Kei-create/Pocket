import SwiftUI

struct ProjectDetailView: View {
    @Environment(PocoStore.self) private var store
    let projectID: UUID

    @State private var showsCompose = false
    @State private var showsFeedbackLimitAlert = false
    @State private var pendingFeedback: Feedback?
    @State private var dropFeedback: Feedback?

    private var project: Project? {
        store.project(id: projectID)
    }

    var body: some View {
        Group {
            if let project {
                if project.isContentLocked {
                    ContentUnavailableView {
                        Label("年齢制限のある作品", systemImage: "lock.fill")
                    } description: {
                        Text("この作品は現在非表示です。成人向けコンテンツの閲覧設定は、将来提供するWebページからのみ変更できます。")
                    }
                    .navigationTitle("非表示の作品")
                    .navigationBarTitleDisplayMode(.inline)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            projectHeader(project)

                            VStack(alignment: .leading, spacing: 12) {
                                Text("この作品について")
                                    .pocoFont(.headline, weight: .medium)
                                Text(project.description)
                                    .pocoFont(.body)
                                    .foregroundStyle(PocoTheme.secondaryText)
                                    .lineSpacing(5)
                            }
                            .padding(20)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .pocoCard()

                            relationshipNotice(project)

                            creatorCard(project)

                            VStack(spacing: 12) {
                                Button {
                                    if store.canSubmitFeedback(to: project.id) {
                                        showsCompose = true
                                    } else {
                                        showsFeedbackLimitAlert = true
                                    }
                                } label: {
                                    Label("感想を送る", systemImage: "bubble.left.and.bubble.right.fill")
                                }
                                .buttonStyle(PocoPrimaryButtonStyle())

                                Text(
                                    "この作品には1人\(PocoLimits.feedbacksPerProject)件まで送れます（現在\(store.ownFeedbackCount(for: project.id))件）"
                                )
                                .pocoFont(.caption)
                                .foregroundStyle(PocoTheme.secondaryText)

                                NavigationLink {
                                    BubbleWallView(projectID: project.id)
                                } label: {
                                    Label("みんなのフキダシを見る", systemImage: "shippingbox")
                                }
                                .buttonStyle(PocoSecondaryButtonStyle())
                            }
                        }
                        .padding(PocoTheme.pagePadding)
                        .padding(.bottom, 24)
                    }
                    .background(PocoTheme.background)
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        PocoAdPlacementView(placement: .project)
                    }
                    .navigationTitle(project.title)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItemGroup(placement: .topBarTrailing) {
                            NavigationLink {
                                QRCodeView(project: project)
                            } label: {
                                Image(systemName: "qrcode")
                            }
                            .accessibilityLabel("QRコードを表示")

                            ShareLink(item: project.deepLinkURL) {
                                Image(systemName: "square.and.arrow.up")
                            }
                            .accessibilityLabel("作品を共有")
                        }
                    }
                    .sheet(isPresented: $showsCompose, onDismiss: showDropIfNeeded) {
                        FeedbackComposeView(project: project) { feedback in
                            pendingFeedback = feedback
                            showsCompose = false
                        }
                    }
                    .fullScreenCover(item: $dropFeedback) { feedback in
                        BubbleDropView(
                            project: project,
                            feedback: feedback,
                            existingFeedbacks: store.feedbacks(for: project.id)
                        ) {
                            await store.submit(feedback)
                        }
                    }
                    .task(id: project.id) {
                        await store.refreshOwnFeedbackCount(for: project.id)
                    }
                    .alert("感想は3件までです", isPresented: $showsFeedbackLimitAlert) {
                        Button("OK", role: .cancel) {}
                    } message: {
                        Text("同じ作品へ送れる感想は、1人につき3件までです。")
                    }
                }
            } else {
                ContentUnavailableView("作品が見つかりません", systemImage: "questionmark.folder")
            }
        }
    }

    private func projectHeader(_ project: Project) -> some View {
        HStack(spacing: 18) {
            ProjectArtworkThumbnail(project: project)
                .frame(width: 118, height: 128)
                .clipShape(RoundedRectangle(cornerRadius: PocoTheme.cornerMedium, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                ProjectRelationshipBadge(project: project)

                Text(project.title)
                    .pocoFont(.title3, weight: .bold)
                Text("\(project.category.creatorPrefix)：\(project.creator.name)")
                    .pocoFont(.subheadline)
                    .foregroundStyle(PocoTheme.secondaryText)
                Label("\(project.feedbackCount.formatted())件の感想", systemImage: "bubble.left")
                    .pocoFont(.subheadline, weight: .medium)
                    .foregroundStyle(PocoTheme.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func creatorCard(_ project: Project) -> some View {
        HStack(spacing: 14) {
            ProfileAvatarView(creator: project.creator, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(project.relationship == .fan ? "作品の作者・クリエイター" : "クリエイター")
                    .pocoFont(.caption)
                    .foregroundStyle(PocoTheme.secondaryText)
                Text(project.creator.name)
                    .pocoFont(.headline, weight: .medium)
            }
            Spacer()
            Image(systemName: "heart.fill")
                .foregroundStyle(PocoTheme.primary.opacity(0.85))
        }
        .padding(18)
        .pocoCard()
    }

    @ViewBuilder
    private func relationshipNotice(_ project: Project) -> some View {
        if project.relationship == .fan || project.verificationStatus != .verified {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: project.relationship.symbolName)
                    .foregroundStyle(PocoTheme.primary)
                    .frame(width: 24)
                Text(relationshipNoticeText(project))
                    .pocoFont(.subheadline)
                    .foregroundStyle(PocoTheme.secondaryText)
                    .lineSpacing(3)
                Spacer(minLength: 0)
            }
            .padding(16)
            .background(PocoTheme.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
            .accessibilityElement(children: .combine)
        }
    }

    private func relationshipNoticeText(_ project: Project) -> String {
        if project.relationship == .fan {
            return "この感想箱はファンが作成した非公式ページです。作品の公式ページではありません。"
        }
        if project.relationship == .authorized {
            return "許可を得ているとして登録されたページです。Pocoによる確認はまだ完了していません。"
        }
        return "制作者本人として登録されたページです。Pocoによる本人確認はまだ完了していません。"
    }

    private func showDropIfNeeded() {
        guard let pendingFeedback else { return }
        self.pendingFeedback = nil
        dropFeedback = pendingFeedback
    }
}

extension Project {
    var deepLinkURL: URL {
        ProjectDeepLink.url(projectID: id)
    }
}
