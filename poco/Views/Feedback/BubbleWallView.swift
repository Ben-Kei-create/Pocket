import SwiftUI

struct BubbleWallView: View {
    @Environment(PocoStore.self) private var store
    let projectID: UUID

    @State private var mode = WallMode.everyone
    @State private var selectedFeedback: Feedback?
    @State private var selectedCreator: Creator?
    @State private var showsMembership = false
    @State private var focusFeedbackID: UUID?
    @State private var previousVisitDate: Date?

    private var project: Project? {
        store.project(id: projectID)
    }

    private var displayedFeedbacks: [Feedback] {
        let values = store.feedbacks(for: projectID)
        return mode == .resonated ? values.sorted { $0.likes > $1.likes } : values
    }

    private var ownFeedbacks: [Feedback] {
        guard let currentUserID = store.currentUserID else { return [] }
        return store.feedbacks(for: projectID).filter { $0.senderID == currentUserID }
    }

    private var ownFeedbackIDs: Set<UUID> {
        Set(ownFeedbacks.map(\.id))
    }

    private var newFeedbackCount: Int {
        guard let previousVisitDate else { return 0 }
        return store.feedbacks(for: projectID).filter { $0.createdAt > previousVisitDate }.count
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

                Picker("表示するフキダシ", selection: modeSelection) {
                    ForEach(WallMode.allCases) { item in
                        Text(
                            item.title
                                + (item == .resonated && !store.capabilities.canSeePopularFeedbacks
                                    ? " 🔒"
                                    : "")
                        )
                            .tag(item)
                    }
                }
                .pickerStyle(.segmented)

                if !ownFeedbacks.isEmpty || newFeedbackCount > 0 {
                    HStack(spacing: 10) {
                        if let ownLatest = ownFeedbacks.first {
                            Button {
                                focusFeedbackID = ownLatest.id
                            } label: {
                                Label("自分のことば", systemImage: "location.fill")
                            }
                            .accessibilityHint("最新の自分のフキダシへ移動します")
                        }

                        if newFeedbackCount > 0 {
                            Button {
                                focusFeedbackID = displayedFeedbacks.first?.id
                            } label: {
                                Label("新着 \(newFeedbackCount)", systemImage: "sparkles")
                            }
                        }
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                PhysicsBubbleFieldView(
                    feedbacks: displayedFeedbacks,
                    highlightedFeedbackIDs: ownFeedbackIDs,
                    focusFeedbackID: focusFeedbackID,
                    onSelect: { selectedFeedback = $0 },
                    onSelectAuthor: { feedback in
                        selectedCreator = feedback.senderCreator
                    }
                )
                .padding(.bottom, 8)
            } else {
                ContentUnavailableView("作品が見つかりません", systemImage: "questionmark.folder")
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
        .background(PocoTheme.background)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            PocoAdPlacementView(placement: .bubbleWall)
        }
        .navigationTitle(project?.title ?? "みんなのフキダシ")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedFeedback) { feedback in
            BubbleDetailSheet(feedbackID: feedback.id)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedCreator) { creator in
            NavigationStack {
                PublicProfileView(creator: creator)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("閉じる") {
                                selectedCreator = nil
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $showsMembership) {
            PocoMembershipView()
        }
        .task(id: projectID) {
            if previousVisitDate == nil {
                let timestamp = UserDefaults.standard.double(
                    forKey: "poco.lastBubbleVisit.\(projectID.uuidString)"
                )
                previousVisitDate = timestamp > 0
                    ? Date(timeIntervalSince1970: timestamp)
                    : .now
            }
            await store.loadFeedbacks(for: projectID)
            guard !Task.isCancelled else { return }
            store.startObservingFeedbacks(for: projectID)
        }
        .onDisappear {
            UserDefaults.standard.set(
                Date.now.timeIntervalSince1970,
                forKey: "poco.lastBubbleVisit.\(projectID.uuidString)"
            )
            store.stopObservingFeedbacks(for: projectID)
        }
        .onChange(of: store.capabilities.canSeePopularFeedbacks) { _, canSeePopular in
            if !canSeePopular {
                mode = .everyone
            }
        }
    }

    private var modeSelection: Binding<WallMode> {
        Binding(
            get: { mode },
            set: { newValue in
                if newValue == .resonated && !store.capabilities.canSeePopularFeedbacks {
                    showsMembership = true
                } else {
                    mode = newValue
                }
            }
        )
    }
}

private enum WallMode: String, CaseIterable, Identifiable {
    case everyone
    case resonated

    var id: Self { self }
    var title: String {
        switch self {
        case .everyone: "みんなのフキダシ"
        case .resonated: "共感のフキダシ"
        }
    }
}
