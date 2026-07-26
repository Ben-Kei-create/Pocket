import SwiftUI

struct BubbleWallView: View {
    @Environment(PocoStore.self) private var store
    let projectID: UUID

    @State private var mode = WallMode.everyone
    @State private var selectedFeedback: Feedback?

    private var project: Project? {
        store.project(id: projectID)
    }

    private var displayedFeedbacks: [Feedback] {
        let values = store.feedbacks(for: projectID)
        return mode == .popular ? values.sorted { $0.likes > $1.likes } : values
    }

    var body: some View {
        VStack(spacing: 14) {
            if let project {
                VStack(spacing: 5) {
                    Label("\(project.feedbackCount.formatted())", systemImage: "bubble.left")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(PocoTheme.primary)
                    Text("件の感想")
                        .font(.caption)
                        .foregroundStyle(PocoTheme.secondaryText)
                }

                Picker("表示するフキダシ", selection: $mode) {
                    ForEach(WallMode.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.segmented)

                GlassJarView {
                    BubblePileView(
                        feedbacks: displayedFeedbacks,
                        isInteractive: true,
                        onSelect: { selectedFeedback = $0 }
                    )
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 8)
            } else {
                ContentUnavailableView("作品が見つかりません", systemImage: "questionmark.folder")
            }
        }
        .padding(.horizontal, PocoTheme.pagePadding)
        .padding(.bottom, 8)
        .background(PocoTheme.background)
        .navigationTitle(project?.title ?? "みんなのフキダシ")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedFeedback) { feedback in
            BubbleDetailSheet(feedbackID: feedback.id)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .task(id: projectID) {
            await store.loadFeedbacks(for: projectID)
            guard !Task.isCancelled else { return }
            store.startObservingFeedbacks(for: projectID)
        }
        .onDisappear {
            store.stopObservingFeedbacks(for: projectID)
        }
    }
}

private enum WallMode: String, CaseIterable, Identifiable {
    case everyone
    case popular

    var id: Self { self }
    var title: String {
        switch self {
        case .everyone: "みんなのフキダシ"
        case .popular: "人気のフキダシ"
        }
    }
}
