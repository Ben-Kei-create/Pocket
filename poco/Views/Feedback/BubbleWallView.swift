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
        store.feedbacks(for: projectID)
    }

    private var ownFeedbacks: [Feedback] {
        store.feedbacks(for: projectID).filter(store.owns)
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
                                + (item == .insights && !store.capabilities.canSeePopularFeedbacks
                                    ? " 🔒"
                                    : "")
                        )
                            .tag(item)
                    }
                }
                .pickerStyle(.segmented)

                if mode == .everyone && (!ownFeedbacks.isEmpty || newFeedbackCount > 0) {
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

                if mode == .everyone {
                    PhysicsBubbleFieldView(
                        feedbacks: displayedFeedbacks,
                        highlightedFeedbackIDs: ownFeedbackIDs,
                        focusFeedbackID: focusFeedbackID,
                        enablesCompanionEvolution: store.capabilities.canUseCompanionEvolution,
                        onSelect: { selectedFeedback = $0 },
                        onSelectAuthor: { feedback in
                            selectedCreator = feedback.senderCreator
                        },
                        onCompanionTapped: { eventKey in
                            store.awardStarCoins(1, eventKey: eventKey)
                        },
                        onRareCompanionBorn: { eventKey in
                            store.awardStarCoins(5, eventKey: eventKey)
                        },
                        onRareCompanionTapped: { eventKey in
                            store.awardStarCoins(1, eventKey: eventKey)
                        }
                    )
                    .padding(.bottom, 8)
                } else {
                    ProjectInsightSummaryView(
                        project: project,
                        feedbacks: displayedFeedbacks
                    )
                }
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                StarCoinBadge(balance: store.starCoinBalance)
            }
        }
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
                if newValue == .insights && !store.capabilities.canSeePopularFeedbacks {
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
    case insights

    var id: Self { self }
    var title: String {
        switch self {
        case .everyone: "みんなのフキダシ"
        case .insights: "作品の記録"
        }
    }
}

private struct ProjectInsightSummaryView: View {
    let project: Project
    let feedbacks: [Feedback]

    private var totalLikes: Int {
        feedbacks.reduce(0) { $0 + $1.likes }
    }

    private var receivedCount: Int {
        feedbacks.filter { $0.creatorReceivedAt != nil }.count
    }

    private var recentCount: Int {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        return feedbacks.filter { $0.createdAt >= sevenDaysAgo }.count
    }

    private var averageLength: Int {
        guard !feedbacks.isEmpty else { return 0 }
        return feedbacks.reduce(0) { $0 + $1.message.count } / feedbacks.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("この作品に届いたことば")
                    .font(.headline)

                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 12
                ) {
                    insightCard(
                        value: project.feedbackCount,
                        title: "感想",
                        symbol: "bubble.left.fill",
                        color: PocoTheme.primary
                    )
                    insightCard(
                        value: totalLikes,
                        title: "共感",
                        symbol: "heart.fill",
                        color: .pink
                    )
                    insightCard(
                        value: receivedCount,
                        title: "作者のいいね",
                        symbol: "heart.fill",
                        color: PocoTheme.primary
                    )
                    insightCard(
                        value: recentCount,
                        title: "最近7日間",
                        symbol: "calendar",
                        color: .mint
                    )
                }

                VStack(alignment: .leading, spacing: 10) {
                    Label("ことばの傾向", systemImage: "text.quote")
                        .font(.headline)
                    Text("感想は平均\(averageLength)文字。ランキングではなく、作品へ届いたことば全体の記録です。")
                        .font(.subheadline)
                        .foregroundStyle(PocoTheme.secondaryText)
                        .lineSpacing(4)
                }
                .padding(18)
                .pocoCard()

                VStack(alignment: .leading, spacing: 7) {
                    Text(project.title)
                        .font(.headline)
                    Text("\(project.category.creatorPrefix)：\(project.creator.name)")
                        .font(.subheadline)
                        .foregroundStyle(PocoTheme.secondaryText)
                    Text(project.description)
                        .font(.footnote)
                        .foregroundStyle(PocoTheme.secondaryText)
                        .lineLimit(3)
                }
                .padding(18)
                .pocoCard()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
    }

    private func insightCard(
        value: Int,
        title: String,
        symbol: String,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .foregroundStyle(color)
            Text(value.formatted())
                .font(.title2.bold().monospacedDigit())
            Text(title)
                .font(.caption)
                .foregroundStyle(PocoTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .padding(16)
        .pocoCard()
        .accessibilityElement(children: .combine)
    }
}
