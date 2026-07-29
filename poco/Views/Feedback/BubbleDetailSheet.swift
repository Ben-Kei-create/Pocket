import SwiftUI

struct BubbleDetailSheet: View {
    @Environment(PocoStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let feedbackID: UUID
    @State private var selectedCreator: Creator?
    @State private var showsReport = false
    @State private var showsDeleteConfirmation = false
    @State private var showsHideConfirmation = false
    @State private var showsReportedConfirmation = false
    @State private var isModerating = false

    private var feedback: Feedback? {
        store.feedbacks.first { $0.id == feedbackID }
    }

    private var hasLiked: Bool {
        store.likedFeedbackIDs.contains(feedbackID)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let feedback {
                    VStack(alignment: .leading, spacing: 24) {
                        BubbleView(
                            feedback: feedback,
                            onSelectAuthor: { selectedCreator = $0 }
                        )
                            .frame(maxWidth: .infinity, minHeight: 190)

                        HStack {
                            Label(
                                PocoDateFormatting.feedbackTimestamp.string(from: feedback.createdAt),
                                systemImage: "clock"
                            )
                            Spacer()
                            if store.capabilities.canSeePopularFeedbacks {
                                Label("\(feedback.likes)", systemImage: "heart.fill")
                            }
                        }
                        .pocoFont(.subheadline)
                        .foregroundStyle(PocoTheme.secondaryText)

                        Button {
                            Task {
                                await store.like(feedback)
                            }
                        } label: {
                            Label(
                                hasLiked ? "いいねを送りました" : "いいねを送る",
                                systemImage: hasLiked ? "heart.fill" : "heart"
                            )
                        }
                        .buttonStyle(PocoPrimaryButtonStyle())
                        .disabled(hasLiked)
                        .accessibilityHint(
                            store.canMarkReceived(feedback)
                                ? "作者としていいねし、フキダシに作者のハートを付けます"
                                : store.capabilities.canSeePopularFeedbacks
                                    ? "現在のいいね数は\(feedback.likes)件です"
                                    : "ゲストにはいいね数は表示されません"
                        )

                        if feedback.creatorReceivedAt != nil {
                            Label("作者もいいねしました", systemImage: "heart.fill")
                                .pocoFont(.subheadline, weight: .medium)
                                .foregroundStyle(PocoTheme.primary)
                                .accessibilityLabel("作者がこの感想にいいねしました")
                        }

                        Spacer()
                    }
                    .padding(PocoTheme.pagePadding)
                } else {
                    ContentUnavailableView("感想が見つかりません", systemImage: "bubble.left")
                }
            }
            .background(PocoTheme.background)
            .navigationTitle("フキダシ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if let feedback {
                        Menu {
                            Button {
                                showsReport = true
                            } label: {
                                Label("通報する", systemImage: "exclamationmark.bubble")
                            }

                            if store.owns(feedback) {
                                Button(role: .destructive) {
                                    showsDeleteConfirmation = true
                                } label: {
                                    Label("自分の感想を削除", systemImage: "trash")
                                }
                            } else if store.canHideAsCreator(feedback) {
                                Button(role: .destructive) {
                                    showsHideConfirmation = true
                                } label: {
                                    Label("作品から非表示", systemImage: "eye.slash")
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .disabled(isModerating)
                        .accessibilityLabel("フキダシのその他の操作")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる", action: dismiss.callAsFunction)
                }
            }
            .navigationDestination(item: $selectedCreator) { creator in
                PublicProfileView(creator: creator)
            }
            .sheet(isPresented: $showsReport) {
                if let feedback {
                    FeedbackReportSheet(feedback: feedback) {
                        showsReportedConfirmation = true
                    }
                }
            }
            .alert("通報を受け付けました", isPresented: $showsReportedConfirmation) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("ご協力ありがとうございます。Poco運営が確認します。")
            }
            .confirmationDialog(
                "この感想を削除しますか？",
                isPresented: $showsDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("削除する", role: .destructive) {
                    guard let feedback else { return }
                    moderate { await store.deleteOwnFeedback(feedback) }
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text(
                    store.accountStatus == .guest
                        ? "削除した感想は元に戻せません。ゲストは削除しても、この作品へ送れる残り件数が戻りません。"
                        : "削除した感想は元に戻せません。"
                )
            }
            .confirmationDialog(
                "この感想を作品から非表示にしますか？",
                isPresented: $showsHideConfirmation,
                titleVisibility: .visible
            ) {
                Button("非表示にする", role: .destructive) {
                    guard let feedback else { return }
                    moderate { await store.hideAsCreator(feedback) }
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("投稿者の記録は保持され、Poco運営による確認と復旧が可能です。")
            }
        }
    }

    private func moderate(
        operation: @escaping @MainActor () async -> Result<Void, AppError>
    ) {
        guard !isModerating else { return }
        isModerating = true
        Task {
            let result = await operation()
            isModerating = false
            if case .success = result {
                dismiss()
            }
        }
    }
}
