import SwiftUI

struct BubbleDetailSheet: View {
    @Environment(PocoStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let feedbackID: UUID

    private var feedback: Feedback? {
        store.feedbacks.first { $0.id == feedbackID }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let feedback {
                    VStack(alignment: .leading, spacing: 24) {
                        BubbleView(feedback: feedback)
                            .frame(maxWidth: .infinity, minHeight: 190)

                        HStack {
                            Label(feedback.createdAt.formatted(date: .abbreviated, time: .shortened), systemImage: "clock")
                            Spacer()
                            Label("\(feedback.likes)", systemImage: "heart.fill")
                        }
                        .font(.subheadline)
                        .foregroundStyle(PocoTheme.secondaryText)

                        Button {
                            Task {
                                await store.like(feedback)
                            }
                        } label: {
                            Label("いいね", systemImage: "heart")
                        }
                        .buttonStyle(PocoPrimaryButtonStyle())

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
        }
    }
}
