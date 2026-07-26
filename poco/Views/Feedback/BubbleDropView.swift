import SwiftUI
import UIKit

struct BubbleDropView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let project: Project
    let feedback: Feedback
    let existingFeedbacks: [Feedback]
    let onDelivered: () async -> Result<Void, AppError>

    @State private var dragOffset: CGSize = .zero
    @State private var isDropped = false
    @State private var showsSuccess = false
    @State private var showsWall = false
    @State private var deliveryState = DeliveryState.idle

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ZStack(alignment: .bottom) {
                    PocoTheme.background.ignoresSafeArea()

                    VStack(spacing: 5) {
                        Text(isDropped ? "あなたのことばが届きました" : "フキダシをビンへ")
                            .font(.title2.weight(.bold))
                        Text(isDropped ? "クリエイターのチカラになります" : "下へスワイプ、またはドラッグしておとしてみよう")
                            .font(.subheadline)
                            .foregroundStyle(PocoTheme.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 20)

                    GlassJarView {
                        BubblePileView(feedbacks: existingFeedbacks)
                    }
                    .frame(width: proxy.size.width - 36, height: min(430, proxy.size.height * 0.58))
                    .padding(.bottom, 18)

                    BubbleView(feedback: feedback)
                        .frame(width: min(294, proxy.size.width - 60), height: 126)
                        .rotationEffect(.degrees(isDropped ? -2.5 : 0))
                        .position(x: proxy.size.width / 2, y: 135)
                        .offset(dragOffset)
                        .gesture(dropGesture(in: proxy.size))
                        .allowsHitTesting(!isDropped)
                        .accessibilityHint("下方向へドラッグすると瓶に入ります")
                        .accessibilityAction(named: "瓶におとす") {
                            land(in: proxy.size, horizontalOffset: 0)
                        }

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
        }
        .interactiveDismissDisabled(!isDropped)
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
                Text("フキダシはビンに残っています")
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

    private func dropGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                guard !isDropped else { return }
                let horizontalLimit = size.width * 0.30
                dragOffset = CGSize(
                    width: min(max(value.translation.width, -horizontalLimit), horizontalLimit),
                    height: max(value.translation.height, -18)
                )
            }
            .onEnded { value in
                let shouldDrop = value.translation.height > 75 || value.predictedEndTranslation.height > 145
                if shouldDrop {
                    land(in: size, horizontalOffset: value.translation.width)
                } else {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.74)) {
                        dragOffset = .zero
                    }
                }
            }
    }

    private func land(in size: CGSize, horizontalOffset: CGFloat) {
        guard !isDropped else { return }
        isDropped = true
        let horizontalLimit = size.width * 0.26
        let finalX = min(max(horizontalOffset * 0.42, -horizontalLimit), horizontalLimit)
        let targetY = size.height - min(226, size.height * 0.29)

        let landingAnimation: Animation = reduceMotion
            ? .easeOut(duration: 0.18)
            : .spring(response: 0.55, dampingFraction: 0.72)
        withAnimation(landingAnimation) {
            dragOffset = CGSize(width: finalX, height: targetY - 135)
        }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        Task {
            let landingDelay = reduceMotion ? 180 : 420
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
