import SpriteKit
import SwiftUI
import UIKit

struct PhysicsBubbleFieldView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scrollTrigger = 0

    let feedbacks: [Feedback]
    var highlightedFeedbackIDs: Set<UUID> = []
    var focusFeedbackID: UUID?
    var onSelect: ((Feedback) -> Void)?
    var onSelectAuthor: ((Feedback) -> Void)?

    var body: some View {
        GeometryReader { proxy in
            let layout = BubbleFieldLayout.make(
                feedbacks: feedbacks,
                availableWidth: proxy.size.width
            )
            let worldHeight = max(proxy.size.height, layout.contentHeight)

            BubbleWallPhysicsCanvas(
                feedbacks: feedbacks,
                layout: layout,
                size: proxy.size,
                worldHeight: worldHeight,
                reduceMotion: reduceMotion,
                scrollTrigger: scrollTrigger,
                highlightedFeedbackIDs: highlightedFeedbackIDs,
                focusFeedbackID: focusFeedbackID,
                onSelect: onSelect,
                onSelectAuthor: onSelectAuthor
            )
            .background {
                PocoTheme.cardBackground.opacity(0.28)
            }
            .overlay(alignment: .topTrailing) {
                Label(
                    worldHeight > proxy.size.height ? "上下にスクロール" : "最新",
                    systemImage: worldHeight > proxy.size.height ? "arrow.up.arrow.down" : "arrow.up"
                )
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(PocoTheme.secondaryText)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(.thinMaterial, in: Capsule())
                    .padding(12)
                    .allowsHitTesting(false)
            }
            .accessibilityRepresentation {
                Button {
                    guard let latest = feedbacks.first else { return }
                    onSelect?(latest)
                } label: {
                    Text("感想のフキダシ、\(feedbacks.count)件。画面の上から最新順に表示しています")
                }
                .accessibilityHint("上下にスクロールできます。実行すると最新の感想を開きます")
                .accessibilityAction(named: "古い感想へ") {
                    scrollTrigger -= 1
                }
                .accessibilityAction(named: "新しい感想へ") {
                    scrollTrigger += 1
                }
            }
        }
    }
}

struct PhysicsBubbleDropFieldView: View {
    let feedback: Feedback
    let existingFeedbacks: [Feedback]
    let reduceMotion: Bool
    @Binding var dropTrigger: Int
    let onLanded: () -> Void

    var body: some View {
        GeometryReader { canvas in
            BubbleDropPhysicsCanvas(
                feedback: feedback,
                existingFeedbacks: Array(
                    existingFeedbacks
                        .filter { $0.id != feedback.id }
                        .prefix(BubblePhysicsMetrics.dropPreviewLimit)
                ),
                size: canvas.size,
                reduceMotion: reduceMotion,
                dropTrigger: dropTrigger,
                onLanded: onLanded
            )
        }
        .background(PocoTheme.cardBackground.opacity(0.28))
        .accessibilityRepresentation {
            Button("フキダシをおとす") {
                dropTrigger += 1
            }
            .accessibilityHint("フキダシが上から落下し、ほかのフキダシに着地します")
        }
    }
}

private struct BubbleWallPhysicsCanvas: UIViewRepresentable {
    let feedbacks: [Feedback]
    let layout: BubbleFieldLayout
    let size: CGSize
    let worldHeight: CGFloat
    let reduceMotion: Bool
    let scrollTrigger: Int
    let highlightedFeedbackIDs: Set<UUID>
    let focusFeedbackID: UUID?
    let onSelect: ((Feedback) -> Void)?
    let onSelectAuthor: ((Feedback) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> SKView {
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        view.backgroundColor = .clear
        view.allowsTransparency = true
        view.ignoresSiblingOrder = true
        view.shouldCullNonVisibleNodes = true
        view.isAsynchronous = true
        view.preferredFramesPerSecond = reduceMotion ? 30 : 60
        context.coordinator.present(in: view)
        context.coordinator.attachPanGesture(to: view)
        return view
    }

    func updateUIView(_ view: SKView, context: Context) {
        view.preferredFramesPerSecond = reduceMotion ? 30 : 60
        context.coordinator.update(
            feedbacks: feedbacks,
            layout: layout,
            size: size,
            worldHeight: worldHeight,
            reduceMotion: reduceMotion,
            scrollTrigger: scrollTrigger,
            highlightedFeedbackIDs: highlightedFeedbackIDs,
            focusFeedbackID: focusFeedbackID,
            onSelect: onSelect,
            onSelectAuthor: onSelectAuthor
        )
    }

    static func dismantleUIView(_ view: SKView, coordinator: Coordinator) {
        view.isPaused = true
        view.presentScene(nil)
    }

    @MainActor
    final class Coordinator: NSObject {
        private let scene = BubbleWallPhysicsScene()
        private weak var view: SKView?
        private var handledScrollTrigger = 0
        private var handledFocusFeedbackID: UUID?

        func present(in view: SKView) {
            scene.scaleMode = .resizeFill
            view.presentScene(scene)
        }

        func attachPanGesture(to view: SKView) {
            self.view = view
            let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            panGesture.cancelsTouchesInView = false
            view.addGestureRecognizer(panGesture)
        }

        func update(
            feedbacks: [Feedback],
            layout: BubbleFieldLayout,
            size: CGSize,
            worldHeight: CGFloat,
            reduceMotion: Bool,
            scrollTrigger: Int,
            highlightedFeedbackIDs: Set<UUID>,
            focusFeedbackID: UUID?,
            onSelect: ((Feedback) -> Void)?,
            onSelectAuthor: ((Feedback) -> Void)?
        ) {
            scene.configure(
                feedbacks: feedbacks,
                layout: layout,
                size: size,
                worldHeight: worldHeight,
                reduceMotion: reduceMotion,
                highlightedFeedbackIDs: highlightedFeedbackIDs,
                onSelect: onSelect,
                onSelectAuthor: onSelectAuthor
            )

            if scrollTrigger != handledScrollTrigger {
                let direction: CGFloat = scrollTrigger > handledScrollTrigger ? 1 : -1
                handledScrollTrigger = scrollTrigger
                scene.scrollBy(direction * size.height * 0.78)
            }


            if let focusFeedbackID, focusFeedbackID != handledFocusFeedbackID {
                handledFocusFeedbackID = focusFeedbackID
                scene.scrollTo(feedbackID: focusFeedbackID)
            }
        }

        @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let view else { return }
            let translation = gesture.translation(in: view)
            scene.scrollBy(translation.y)
            gesture.setTranslation(.zero, in: view)
        }
    }
}

private struct BubbleDropPhysicsCanvas: UIViewRepresentable {
    let feedback: Feedback
    let existingFeedbacks: [Feedback]
    let size: CGSize
    let reduceMotion: Bool
    let dropTrigger: Int
    let onLanded: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> SKView {
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        view.backgroundColor = .clear
        view.allowsTransparency = true
        view.ignoresSiblingOrder = true
        view.shouldCullNonVisibleNodes = true
        view.isAsynchronous = true
        view.preferredFramesPerSecond = reduceMotion ? 30 : 60
        context.coordinator.present(in: view)
        return view
    }

    func updateUIView(_ view: SKView, context: Context) {
        view.preferredFramesPerSecond = reduceMotion ? 30 : 60
        context.coordinator.update(
            feedback: feedback,
            existingFeedbacks: existingFeedbacks,
            size: size,
            reduceMotion: reduceMotion,
            dropTrigger: dropTrigger,
            onLanded: onLanded
        )
    }

    static func dismantleUIView(_ view: SKView, coordinator: Coordinator) {
        view.isPaused = true
        view.presentScene(nil)
    }

    @MainActor
    final class Coordinator {
        private let scene = BubbleDropPhysicsScene()
        private var handledDropTrigger = 0

        func present(in view: SKView) {
            scene.scaleMode = .resizeFill
            view.presentScene(scene)
        }

        func update(
            feedback: Feedback,
            existingFeedbacks: [Feedback],
            size: CGSize,
            reduceMotion: Bool,
            dropTrigger: Int,
            onLanded: @escaping () -> Void
        ) {
            scene.configure(
                feedback: feedback,
                existingFeedbacks: existingFeedbacks,
                size: size,
                reduceMotion: reduceMotion,
                onLanded: onLanded
            )

            if dropTrigger > handledDropTrigger {
                handledDropTrigger = dropTrigger
                scene.releasePendingBubble()
            }
        }
    }
}
