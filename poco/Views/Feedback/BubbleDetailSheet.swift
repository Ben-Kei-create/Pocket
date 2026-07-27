import SwiftUI

struct BubbleDetailSheet: View {
    @Environment(PocoStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let feedbackID: UUID
    @State private var selectedCreator: Creator?

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
                            Label(feedback.createdAt.formatted(date: .abbreviated, time: .shortened), systemImage: "clock")
                            Spacer()
                            if store.isPocoMember {
                                Label("\(feedback.likes)", systemImage: "heart.fill")
                            }
                        }
                        .font(.subheadline)
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
                            store.isPocoMember
                                ? "現在のいいね数は\(feedback.likes)件です"
                                : "ゲストにはいいね数は表示されません"
                        )

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
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる", action: dismiss.callAsFunction)
                }
            }
            .navigationDestination(item: $selectedCreator) { creator in
                PublicProfileView(creator: creator)
            }
        }
    }
}
