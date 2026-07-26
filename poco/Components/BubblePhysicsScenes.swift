import SpriteKit
import UIKit

@MainActor
final class BubbleWallPhysicsScene: SKScene, SKPhysicsContactDelegate {
    private var configurationKey: ConfigurationKey?
    private var feedbackByID: [UUID: Feedback] = [:]
    private var oldestFeedbacks: [Feedback] = []
    private var activeBubbleNodes: [UUID: PhysicsBubbleNode] = [:]
    private var onSelect: ((Feedback) -> Void)?
    private var touchStart: CGPoint?
    private var reduceMotion = false
    private var worldHeight: CGFloat = 0
    private let cameraNode = SKCameraNode()

    override init() {
        super.init(size: .zero)
        backgroundColor = .clear
        physicsWorld.contactDelegate = self
    }

    required init?(coder aDecoder: NSCoder) {
        nil
    }

    func configure(
        feedbacks: [Feedback],
        size: CGSize,
        worldHeight: CGFloat,
        reduceMotion: Bool,
        onSelect: ((Feedback) -> Void)?
    ) {
        self.onSelect = onSelect
        let key = ConfigurationKey(
            ids: feedbacks.map(\.id),
            width: Int(size.width.rounded()),
            height: Int(size.height.rounded()),
            worldHeight: Int(worldHeight.rounded()),
            reduceMotion: reduceMotion
        )
        guard key != configurationKey, size.width > 0, size.height > 0 else { return }

        configurationKey = key
        self.reduceMotion = reduceMotion
        self.size = size
        self.worldHeight = max(size.height, worldHeight)
        physicsWorld.gravity = .zero
        rebuild(feedbacks: feedbacks)
    }

    func scrollBy(_ distance: CGFloat) {
        guard worldHeight > size.height else { return }
        let minimumY = size.height / 2
        let maximumY = worldHeight - size.height / 2
        cameraNode.position.y = min(max(cameraNode.position.y + distance, minimumY), maximumY)
        updateVisibleBubbleNodes()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchStart = touches.first.map { $0.location(in: self) }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)
        defer { touchStart = nil }

        if let touchStart, hypot(point.x - touchStart.x, point.y - touchStart.y) > 14 {
            return
        }

        guard let bubble = bubbleNode(at: point),
              let feedback = feedbackByID[bubble.feedbackID] else { return }
        if !reduceMotion {
            bubble.physicsBody?.applyImpulse(CGVector(dx: 0, dy: 0.18))
            bubble.playPoyon()
        }
        onSelect?(feedback)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchStart = nil
    }

    func didBegin(_ contact: SKPhysicsContact) {
        guard !reduceMotion else { return }
        (contact.bodyA.node as? PhysicsBubbleNode)?.playPoyon()
        (contact.bodyB.node as? PhysicsBubbleNode)?.playPoyon()
    }

    private func bubbleNode(at point: CGPoint) -> PhysicsBubbleNode? {
        for hitNode in nodes(at: point) {
            var currentNode: SKNode? = hitNode
            while let node = currentNode {
                if let bubble = node as? PhysicsBubbleNode {
                    return bubble
                }
                currentNode = node.parent
            }
        }
        return nil
    }

    private func rebuild(feedbacks: [Feedback]) {
        removeAllChildren()
        feedbackByID = Dictionary(uniqueKeysWithValues: feedbacks.map { ($0.id, $0) })
        oldestFeedbacks = Array(feedbacks.reversed())
        activeBubbleNodes.removeAll(keepingCapacity: true)
        addPhysicsBoundaries(to: self, height: worldHeight)
        addOldestFeedbackMarker()

        cameraNode.position = CGPoint(
            x: size.width / 2,
            y: max(size.height / 2, worldHeight - size.height / 2)
        )
        addChild(cameraNode)
        camera = cameraNode
        updateVisibleBubbleNodes()
    }

    private func updateVisibleBubbleNodes() {
        guard !oldestFeedbacks.isEmpty else { return }

        let bubbleSize = BubblePhysicsMetrics.wallBubbleSize(for: size.width)
        let columnCount = BubblePhysicsMetrics.wallColumnCount
        let columnWidth = size.width / CGFloat(columnCount)
        let columns = (0..<columnCount).map {
            columnWidth * (CGFloat($0) + 0.5)
        }
        let visibleMinimumY = cameraNode.position.y - size.height / 2 - BubblePhysicsMetrics.rowSpacing * 2
        let visibleMaximumY = cameraNode.position.y + size.height / 2 + BubblePhysicsMetrics.rowSpacing * 2
        let minimumRow = max(
            0,
            Int(
                floor(
                    (visibleMinimumY - BubblePhysicsMetrics.wallBottomStartY)
                        / BubblePhysicsMetrics.rowSpacing
                )
            )
        )
        let maximumRow = min(
            (oldestFeedbacks.count - 1) / columnCount,
            Int(
                ceil(
                    (visibleMaximumY - BubblePhysicsMetrics.wallBottomStartY)
                        / BubblePhysicsMetrics.rowSpacing
                )
            )
        )
        let startIndex = min(oldestFeedbacks.count, minimumRow * columnCount)
        let endIndex = min(oldestFeedbacks.count, (maximumRow + 1) * columnCount)
        guard startIndex < endIndex else { return }
        let visibleFeedbacks = oldestFeedbacks[startIndex..<endIndex]
        let visibleIDs = Set(visibleFeedbacks.map(\.id))

        let idsToRemove = activeBubbleNodes.keys.filter { !visibleIDs.contains($0) }
        for id in idsToRemove {
            activeBubbleNodes[id]?.removeFromParent()
            activeBubbleNodes[id] = nil
        }

        for index in startIndex..<endIndex {
            let feedback = oldestFeedbacks[index]
            guard activeBubbleNodes[feedback.id] == nil else { continue }
            let row = index / columnCount
            let seed = stableSeed(feedback.id)
            let column = index % columnCount
            let jitterX = CGFloat((seed % 5) - 2)
            let jitterY = CGFloat((seed % 5) - 2)
            let node = PhysicsBubbleNode(feedback: feedback, size: bubbleSize)

            node.position = CGPoint(
                x: columns[column] + jitterX,
                y: BubblePhysicsMetrics.wallBottomStartY
                    + CGFloat(row) * BubblePhysicsMetrics.rowSpacing
                    + jitterY
            )
            node.zRotation = reduceMotion
                ? 0
                : CGFloat((seed % 9) - 4) * .pi / 180
            node.physicsBody?.isDynamic = !reduceMotion
            addChild(node)
            activeBubbleNodes[feedback.id] = node
        }
    }

    private func addOldestFeedbackMarker() {
        let marker = SKLabelNode(text: "ここが最初の感想")
        marker.name = "oldest-feedback-marker"
        marker.fontName = UIFont.systemFont(ofSize: 10, weight: .semibold).fontName
        marker.fontSize = 10
        marker.fontColor = UIColor.secondaryLabel.withAlphaComponent(0.7)
        marker.horizontalAlignmentMode = .center
        marker.verticalAlignmentMode = .center
        marker.position = CGPoint(x: size.width / 2, y: 22)
        marker.zPosition = 10
        addChild(marker)
    }
}

@MainActor
final class BubbleDropPhysicsScene: SKScene, SKPhysicsContactDelegate {
    private var configurationKey: ConfigurationKey?
    private var pendingNode: PhysicsBubbleNode?
    private var pendingHasLanded = false
    private var isDraggingPending = false
    private var reduceMotion = false
    private var onLanded: (() -> Void)?

    override init() {
        super.init(size: .zero)
        backgroundColor = .clear
        physicsWorld.contactDelegate = self
    }

    required init?(coder aDecoder: NSCoder) {
        nil
    }

    func configure(
        feedback: Feedback,
        existingFeedbacks: [Feedback],
        size: CGSize,
        reduceMotion: Bool,
        onLanded: @escaping () -> Void
    ) {
        self.onLanded = onLanded
        let key = ConfigurationKey(
            ids: existingFeedbacks.map(\.id) + [feedback.id],
            width: Int(size.width.rounded()),
            height: Int(size.height.rounded()),
            reduceMotion: reduceMotion
        )
        guard key != configurationKey, size.width > 0, size.height > 0 else { return }

        configurationKey = key
        self.reduceMotion = reduceMotion
        self.size = size
        physicsWorld.gravity = CGVector(dx: 0, dy: reduceMotion ? -9 : -3.2)
        rebuild(feedback: feedback, existingFeedbacks: existingFeedbacks)
    }

    func releasePendingBubble() {
        guard let pendingNode, pendingNode.physicsBody?.isDynamic == false else { return }
        isDraggingPending = false
        pendingNode.physicsBody?.isDynamic = true
        pendingNode.physicsBody?.affectedByGravity = true
        if !reduceMotion {
            pendingNode.physicsBody?.applyImpulse(CGVector(dx: 0, dy: -0.12))
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first,
              let pendingNode,
              pendingNode.physicsBody?.isDynamic == false else { return }
        let point = touch.location(in: self)
        isDraggingPending = pendingNode.contains(point)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isDraggingPending, let touch = touches.first, let pendingNode else { return }
        let point = touch.location(in: self)
        let halfWidth = pendingNode.visualSize.width * 0.44
        pendingNode.position = CGPoint(
            x: min(max(point.x, halfWidth + 4), size.width - halfWidth - 4),
            y: min(max(point.y, size.height - 132), size.height - 55)
        )
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isDraggingPending else { return }
        releasePendingBubble()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        isDraggingPending = false
    }

    func didBegin(_ contact: SKPhysicsContact) {
        let bubbleA = contact.bodyA.node as? PhysicsBubbleNode
        let bubbleB = contact.bodyB.node as? PhysicsBubbleNode

        if !reduceMotion {
            bubbleA?.playPoyon()
            bubbleB?.playPoyon()
        }

        guard !pendingHasLanded,
              let pendingNode,
              pendingNode.physicsBody?.isDynamic == true,
              bubbleA === pendingNode || bubbleB === pendingNode else { return }

        let otherBody = bubbleA === pendingNode ? contact.bodyB : contact.bodyA
        let landedCategory = PhysicsCategory.bubble | PhysicsCategory.floor
        guard otherBody.categoryBitMask & landedCategory != 0 else { return }

        pendingHasLanded = true
        onLanded?()
    }

    private func rebuild(feedback: Feedback, existingFeedbacks: [Feedback]) {
        removeAllChildren()
        pendingHasLanded = false
        isDraggingPending = false
        addPhysicsBoundaries(to: self)

        let existingSize = BubblePhysicsMetrics.dropExistingBubbleSize(for: size.width)
        let xInset = existingSize.width / 2 + 7
        let columns = [xInset, max(xInset, size.width - xInset)]

        for (index, existingFeedback) in existingFeedbacks.reversed().enumerated() {
            let row = index / 2
            let seed = stableSeed(existingFeedback.id)
            let node = PhysicsBubbleNode(feedback: existingFeedback, size: existingSize)
            node.position = CGPoint(
                x: columns[(index + seed) % 2],
                y: 45 + CGFloat(row) * BubblePhysicsMetrics.dropRowSpacing
            )
            node.zRotation = reduceMotion ? 0 : CGFloat((seed % 7) - 3) * .pi / 180
            node.physicsBody?.isDynamic = !reduceMotion
            addChild(node)
        }

        let pendingSize = BubblePhysicsMetrics.pendingBubbleSize(for: size.width)
        let pending = PhysicsBubbleNode(feedback: feedback, size: pendingSize)
        pending.position = CGPoint(x: size.width / 2, y: size.height - 72)
        pending.zPosition = 200
        pending.physicsBody?.isDynamic = false
        pending.physicsBody?.affectedByGravity = false
        pending.physicsBody?.contactTestBitMask = PhysicsCategory.bubble | PhysicsCategory.floor
        addChild(pending)
        pendingNode = pending
    }
}
