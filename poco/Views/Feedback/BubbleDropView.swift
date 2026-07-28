import SwiftUI
import UIKit

struct BubbleDropView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(PocoStore.self) private var store
    let project: Project
    let feedback: Feedback
    let existingFeedbacks: [Feedback]
    let onDelivered: () async -> Result<Void, AppError>

    @State private var isDropped = false
    @State private var showsSuccess = false
    @State private var showsWall = false
    @State private var selectedCreator: Creator?
    @State private var deliveryState = DeliveryState.idle
    @State private var dropTrigger = 0

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ZStack(alignment: .bottom) {
                    PocoTheme.background.ignoresSafeArea()

                    VStack(spacing: 5) {
                        Text(isDropped ? "あなたのことばが届きました" : "フキダシをおとそう")
                            .font(.title2.weight(.bold))
                        Text(instructionText)
                            .font(.subheadline)
                            .foregroundStyle(PocoTheme.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 20)

                    PhysicsBubbleDropFieldView(
                        feedback: feedback,
                        existingFeedbacks: existingFeedbacks,
                        reduceMotion: reduceMotion,
                        isScrollEnabled: isDropped,
                        enablesCompanionEvolution: store.capabilities.canUseCompanionEvolution,
                        dropTrigger: $dropTrigger,
                        onLanded: handleLanding,
                        onSelectAuthor: { selectedFeedback in
                            selectedCreator = selectedFeedback.senderCreator
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
                    .frame(
                        width: proxy.size.width,
                        height: min(700, proxy.size.height * 0.84)
                    )

                    if showsSuccess {
                        successCard
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .frame(maxHeight: .infinity, alignment: .top)
                            .padding(.top, 94)
                    }
                }
            }
            .navigationTitle(project.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("閉じる")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    StarCoinBadge(balance: store.starCoinBalance)
                }
            }
            .fullScreenCover(isPresented: $showsWall) {
                NavigationStack {
                    BubbleWallView(projectID: project.id)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("閉じる") {
                                    showsWall = false
                                    dismiss()
                                }
                            }
                        }
                }
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
        }
        .interactiveDismissDisabled(!isDropped)
    }

    private var instructionText: String {
        if isDropped {
            return "上が最新です。下へスクロールすると最初の感想まで見られます"
        }
        return "左右に動かして、空いている場所へおとしてみよう"
    }

    private var successCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: deliveryState.symbolName)
                    .foregroundStyle(deliveryState == .failed ? .orange : PocoTheme.primary)
                Text(deliveryState.title)
                    .font(.headline)
            }

            if deliveryState == .failed {
                Text("フキダシは画面に残っています")
                    .font(.caption)
                    .foregroundStyle(PocoTheme.secondaryText)

                Button("もう一度送信する") {
                    deliver()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PocoTheme.primary)
                .accessibilityHint("同じフキダシの送信を再試行します")
            } else if deliveryState == .sending {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel("感想を送信中")
            } else {
                Button("みんなのフキダシを見る") {
                    showsWall = true
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PocoTheme.primary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: PocoTheme.cornerMedium, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 16, y: 8)
    }

    private func handleLanding() {
        guard !isDropped else { return }
        isDropped = true

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        Task {
            let landingDelay = reduceMotion ? 80 : 220
            try? await Task.sleep(for: .milliseconds(landingDelay))
            deliver()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
                showsSuccess = true
            }
        }
    }

    private func deliver() {
        guard deliveryState != .sending else { return }
        deliveryState = .sending

        Task {
            let result = await onDelivered()
            switch result {
            case .success:
                deliveryState = .delivered
            case .failure:
                deliveryState = .failed
            }
        }
    }
}

private enum DeliveryState: Equatable {
    case idle
    case sending
    case delivered
    case failed

    var title: String {
        switch self {
        case .idle, .sending:
            "送信しています"
        case .delivered:
            "届きました！"
        case .failed:
            "送信できませんでした"
        }
    }

    var symbolName: String {
        switch self {
        case .idle, .sending:
            "arrow.up.circle.fill"
        case .delivered:
            "checkmark.circle.fill"
        case .failed:
            "exclamationmark.circle.fill"
        }
    }
}
