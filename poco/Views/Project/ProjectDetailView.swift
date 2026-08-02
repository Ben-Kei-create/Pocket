import SwiftUI

struct ProjectDetailView: View {
    @Environment(PocoStore.self) private var store
    let projectID: UUID

    @State private var showsCompose = false
    @State private var showsFeedbackLimitAlert = false
    @State private var pendingFeedback: Feedback?
    @State private var dropFeedback: Feedback?
    @State private var showsRightsHolderRequest = false
    @State private var showsQuestionCompose = false
    @State private var showsQuestionRegistration = false
    @State private var opensQuestionAfterRegistration = false
    @State private var selectedBadge: StarStoreItem?

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

                            creatorCard(project)

                            if !equippedBadges.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("この作品のバッジ")
                                        .pocoFont(.caption, weight: .medium)
                                        .foregroundStyle(PocoTheme.secondaryText)
                                    ProjectBadgeCaseView(
                                        items: equippedBadges,
                                        onSelect: { selectedBadge = $0 }
                                    )
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            VStack(alignment: .leading, spacing: 12) {
                                Text("この作品について")
                                    .pocoFont(.headline, weight: .medium)
                                Text(project.description)
                                    .pocoFont(.body)
                                    .foregroundStyle(PocoTheme.secondaryText)
                                    .lineSpacing(5)

                                if let externalURL = project.externalURL {
                                    Divider()
                                    Link(destination: externalURL) {
                                        HStack(spacing: 12) {
                                            Image(systemName: "link")
                                                .foregroundStyle(PocoTheme.primary)
                                                .frame(width: 24)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("作品ページを開く")
                                                    .pocoFont(.subheadline, weight: .medium)
                                                    .foregroundStyle(.primary)
                                                Text(externalURL.host ?? externalURL.absoluteString)
                                                    .pocoFont(.caption)
                                                    .foregroundStyle(PocoTheme.secondaryText)
                                                    .lineLimit(1)
                                            }
                                            Spacer()
                                            Image(systemName: "arrow.up.right")
                                                .pocoFont(.caption, weight: .bold)
                                                .foregroundStyle(PocoTheme.primary)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("作品の外部ページを開く")
                                    .accessibilityHint("Safariで\(externalURL.host ?? "外部サイト")を開きます")
                                }
                            }
                            .padding(20)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .pocoCard()

                            VStack(spacing: 12) {
                                Button {
                                    if store.canSubmitFeedback(to: project.id) {
                                        showsCompose = true
                                    } else {
                                        showsFeedbackLimitAlert = true
                                    }
                                } label: {
                                    Label(
                                        store.feedbackDraft(for: project.id) == nil
                                            ? "感想を送る"
                                            : "下書きを再開",
                                        systemImage: store.feedbackDraft(for: project.id) == nil
                                            ? "bubble.left.and.bubble.right.fill"
                                            : "doc.text.fill"
                                    )
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

                                if project.acceptsQuestions,
                                   project.creator.id != store.currentUserID {
                                    Button {
                                        if store.accountStatus == .registered {
                                            showsQuestionCompose = true
                                        } else {
                                            opensQuestionAfterRegistration = true
                                            showsQuestionRegistration = true
                                        }
                                    } label: {
                                        Label(
                                            qAndAButtonTitle(project),
                                            systemImage: "questionmark.bubble"
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .pocoFont(.subheadline, weight: .medium)
                                    .foregroundStyle(PocoTheme.primary)
                                    .padding(.top, 4)
                                }
                            }

                            relationshipNotice(project)
                        }
                        .padding(PocoTheme.pagePadding)
                        .padding(.bottom, 24)
                    }
                    .background(ProjectDecorationBackground(projectID: project.id))
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        PocoAdPlacementView(placement: .project)
                    }
                    .navigationTitle("")
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

                            Menu {
                                Button {
                                    showsRightsHolderRequest = true
                                } label: {
                                    Label("権利に関する削除申請", systemImage: "checkmark.shield")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                            }
                            .accessibilityLabel("作品のその他の操作")
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
                    .sheet(isPresented: $showsRightsHolderRequest) {
                        ProjectRightsHolderRequestView(project: project)
                    }
                    .sheet(isPresented: $showsQuestionCompose) {
                        QAndAComposeView(project: project)
                    }
                    .sheet(
                        isPresented: $showsQuestionRegistration,
                        onDismiss: {
                            guard opensQuestionAfterRegistration else { return }
                            opensQuestionAfterRegistration = false
                            if store.accountStatus == .registered {
                                showsQuestionCompose = true
                            }
                        }
                    ) {
                        RegistrationGateView(context: .account)
                    }
                    .sheet(item: $selectedBadge) { item in
                        BadgeDetailSheet(item: item)
                    }
                    .task(id: project.id) {
                        async let decoration: Void = store.loadProjectDecoration(
                            projectID: project.id
                        )
                        await store.refreshOwnFeedbackCount(for: project.id)
                        _ = await decoration
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

    private var equippedBadges: [StarStoreItem] {
        let decoration = store.projectDecoration(for: projectID)
        return (0..<3).compactMap { slot in
            store.starStoreItem(id: decoration.badgeItemID(slot: slot))
        }
    }

    private func projectHeader(_ project: Project) -> some View {
        HStack(spacing: 18) {
            ProjectArtworkThumbnail(project: project)
                .frame(width: 118, height: 128)
                .clipShape(RoundedRectangle(cornerRadius: PocoTheme.cornerMedium, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                if project.purpose == .event {
                    ProjectPurposeBadge(purpose: project.purpose)
                }

                Text(project.title)
                    .pocoFont(.title3, weight: .bold)
                Label("\(project.feedbackCount.formatted())件の感想", systemImage: "bubble.left")
                    .pocoFont(.subheadline, weight: .medium)
                    .foregroundStyle(PocoTheme.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func creatorCard(_ project: Project) -> some View {
        NavigationLink {
            PublicProfileView(creator: project.creator)
        } label: {
            HStack(spacing: 14) {
                ProfileAvatarView(creator: project.creator, size: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Text(creatorCardTitle(project))
                        .pocoFont(.caption)
                        .foregroundStyle(PocoTheme.secondaryText)
                    Text(project.creator.name)
                        .pocoFont(.headline, weight: .medium)
                        .foregroundStyle(.primary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .pocoFont(.caption, weight: .bold)
                    .foregroundStyle(PocoTheme.secondaryText)
            }
            .padding(18)
            .pocoCard()
        }
        .buttonStyle(.plain)
        .accessibilityHint("公開プロフィールを表示します")
    }

    private func creatorCardTitle(_ project: Project) -> String {
        switch project.relationship {
        case .creator: "クリエイター"
        case .authorized: "感想箱の登録者"
        case .fan: "この感想箱を作った人"
        }
    }

    private func qAndAButtonTitle(_ project: Project) -> String {
        switch project.relationship {
        case .creator:
            "Q&Aで質問する"
        case .authorized, .fan:
            "感想箱の作成者に質問する"
        }
    }

    @ViewBuilder
    private func relationshipNotice(_ project: Project) -> some View {
        if project.purpose == .event {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: project.purpose.symbolName)
                    .foregroundStyle(.orange)
                    .frame(width: 24)
                Text("イベントや頒布の場で感想を集めるページです。")
                    .pocoFont(.subheadline)
                    .foregroundStyle(PocoTheme.secondaryText)
                    .lineSpacing(3)
                Spacer(minLength: 0)
            }
            .padding(16)
            .background(Color.orange.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
            .accessibilityElement(children: .combine)
        }

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
