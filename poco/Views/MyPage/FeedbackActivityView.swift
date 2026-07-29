import SwiftUI

enum FeedbackActivityKind {
    case sent
    case liked

    var title: String {
        switch self {
        case .sent: "送った感想"
        case .liked: "いいねしたフキダシ"
        }
    }

    var emptyTitle: String {
        switch self {
        case .sent: "送った感想はまだありません"
        case .liked: "いいねしたフキダシはまだありません"
        }
    }

    var emptyMessage: String {
        switch self {
        case .sent: "作品にことばを届けると、ここからいつでも見返せます。"
        case .liked: "心に残ったフキダシへいいねを送ると、ここに残ります。"
        }
    }

    var symbolName: String {
        switch self {
        case .sent: "bubble.left"
        case .liked: "heart"
        }
    }
}

struct FeedbackActivityView: View {
    @Environment(PocoStore.self) private var store
    let kind: FeedbackActivityKind

    @State private var selectedFeedback: Feedback?

    private var feedbacks: [Feedback] {
        switch kind {
        case .sent: store.sentFeedbacks
        case .liked: store.likedFeedbacks
        }
    }

    var body: some View {
        Group {
            if feedbacks.isEmpty {
                emptyContent
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(feedbacks) { feedback in
                            Button {
                                selectedFeedback = feedback
                            } label: {
                                FeedbackActivityRow(
                                    feedback: feedback,
                                    projectTitle: store.project(id: feedback.projectID)?.title,
                                    showsVisibility: kind == .sent
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(PocoTheme.pagePadding)
                }
                .refreshable {
                    await store.loadMyActivity()
                }
            }
        }
        .background(PocoTheme.groupedBackground)
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await store.loadMyActivity()
        }
        .sheet(item: $selectedFeedback) { feedback in
            BubbleDetailSheet(feedbackID: feedback.id)
        }
    }

    @ViewBuilder
    private var emptyContent: some View {
        switch store.activityLoadState {
        case .idle, .loading:
            ProgressView("読み込んでいます")
        case .error:
            ContentUnavailableView {
                Label("読み込めませんでした", systemImage: "wifi.exclamationmark")
            } description: {
                Text("通信環境を確認して、もう一度お試しください。")
            } actions: {
                Button("もう一度試す") {
                    Task { await store.loadMyActivity() }
                }
                .buttonStyle(.borderedProminent)
                .tint(PocoTheme.primary)
            }
        case .loaded:
            ContentUnavailableView {
                Label(kind.emptyTitle, systemImage: kind.symbolName)
            } description: {
                Text(kind.emptyMessage)
            }
        }
    }
}

private struct FeedbackActivityRow: View {
    let feedback: Feedback
    let projectTitle: String?
    let showsVisibility: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: "bubble.left.fill")
                .pocoFont(.title3)
                .foregroundStyle(Color(uiColor: .label).opacity(0.58))
                .frame(width: 42, height: 42)
                .background(PocoTheme.bubble(feedback.bubbleColor), in: Circle())

            VStack(alignment: .leading, spacing: 7) {
                Text(feedback.message)
                    .pocoFont(.subheadline, weight: .medium)
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let projectTitle {
                    Text(projectTitle)
                        .pocoFont(.caption, weight: .medium)
                        .foregroundStyle(PocoTheme.secondaryText)
                        .lineLimit(1)
                }

                HStack(spacing: 7) {
                    Text(PocoDateFormatting.feedbackTimestamp.string(from: feedback.createdAt))
                    if showsVisibility {
                        Label(
                            feedback.isPublic ? "公開" : "非公開",
                            systemImage: feedback.isPublic ? "globe" : "lock.fill"
                        )
                    }
                }
                .pocoFont(.caption)
                .foregroundStyle(PocoTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

                if feedback.creatorReceivedAt != nil {
                    Label("作者もいいねしました", systemImage: "heart.fill")
                        .pocoFont(.caption, weight: .medium)
                        .foregroundStyle(PocoTheme.primary)
                }
            }

            Image(systemName: "chevron.right")
                .pocoFont(.caption, weight: .medium)
                .foregroundStyle(PocoTheme.tertiaryText)
                .padding(.top, 4)
        }
        .padding(15)
        .pocoCard(cornerRadius: PocoTheme.cornerSmall)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("フキダシの詳細を開きます")
    }
}
