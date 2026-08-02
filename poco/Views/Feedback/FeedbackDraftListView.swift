import SwiftUI

struct FeedbackDraftListView: View {
    @Environment(PocoStore.self) private var store

    var body: some View {
        Group {
            if store.currentFeedbackDrafts.isEmpty {
                ContentUnavailableView(
                    "下書きはありません",
                    systemImage: "doc.text"
                )
            } else {
                List {
                    ForEach(store.currentFeedbackDrafts) { draft in
                        if let project = store.project(id: draft.projectID) {
                            NavigationLink {
                                ProjectDetailView(projectID: project.id)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(project.title)
                                        .pocoFont(.headline, weight: .medium)
                                    Text(draft.message)
                                        .pocoFont(.subheadline)
                                        .foregroundStyle(PocoTheme.secondaryText)
                                        .lineLimit(2)
                                    Text(draft.updatedAt, format: .relative(presentation: .named))
                                        .pocoFont(.caption)
                                        .foregroundStyle(PocoTheme.tertiaryText)
                                }
                                .padding(.vertical, 5)
                            }
                            .swipeActions {
                                Button("削除", role: .destructive) {
                                    store.discardFeedbackDraft(for: draft.projectID)
                                }
                            }
                            .accessibilityHint("作品ページから下書きを再開します")
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("感想の下書き")
        .navigationBarTitleDisplayMode(.inline)
    }
}
