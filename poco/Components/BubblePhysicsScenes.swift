import SpriteKit
import UIKit

@MainActor
final class BubbleWallPhysicsScene: SKScene, SKPhysicsContactDelegate {
    private var configurationKey: ConfigurationKey?
    private var feedbackByID: [UUID: Feedback] = [:]
    private var oldestFeedbacks: [Feedback] = []
    private var placementByID: [UUID: BubbleFieldPlacement] = [:]
    private var activeBubbleNodes: [UUID: PhysicsBubbleNode] = [:]
    private var activeCompanionNodes: [UUID: PhysicsCompanionNode] = [:]
    private var highlightedFeedbackIDs: Set<UUID> = []
    private var onSelect: ((Feedback) -> Void)?
    private var onSelectAuthor: ((Feedback) -> Void)?
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
        layout: BubbleFieldLayout,
        size: CGSize,
        worldHeight: CGFloat,
        reduceMotion: Bool,
        highlightedFeedbackIDs: Set<UUID>,
        onSelect: ((Feedback) -> Void)?,
        onSelectAuthor: ((Feedback) -> Void)?
    ) {
        self.onSelect = onSelect
        self.onSelectAuthor = onSelectAuthor
        let key = ConfigurationKey(
            ids: feedbacks.map(\.id),
            highlightedIDs: highlightedFeedbackIDs.sorted { $0.uuidString < $1.uuidString },
            creatorReceivedIDs: feedbacks
                .filter { $0.creatorReceivedAt != nil }
                .map(\.id)
                .sorted { $0.uuidString < $1.uuidString },
            width: Int(size.width.rounded()),
            height: Int(size.height.rounded()),
            worldHeight: Int(worldHeight.rounded()),
            reduceMotion: reduceMotion
        )
        guard key != configurationKey, size.width > 0, size.height > 0 else { return }

        configurationKey = key
        self.reduceMotion = reduceMotion
        self.highlightedFeedbackIDs = highlightedFeedbackIDs
        self.size = size
        self.worldHeight = max(size.height, worldHeight)
        physicsWorld.gravity = .zero
        rebuild(feedbacks: feedbacks, layout: layout)
    }

    func scrollBy(_ distance: CGFloat) {
        guard worldHeight > size.height else { return }
        let minimumY = size.height / 2
        let maximumY = worldHeight - size.height / 2
        cameraNode.position.y = min(max(cameraNode.position.y + distance, minimumY), maximumY)
        updateVisibleBubbleNodes()
    }

    func scrollTo(feedbackID: UUID) {
        guard let placement = placementByID[feedbackID] else { return }
        let minimumY = size.height / 2
        let maximumY = max(minimumY, worldHeight - size.height / 2)
        cameraNode.position.y = min(max(placement.position.y, minimumY), maximumY)
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

        if let companion = companionNode(at: point) {
            if !reduceMotion {
                companion.physicsBody?.applyImpulse(CGVector(dx: 0, dy: 0.10))
                companion.playPoyon()
            }
            return
        }

        guard let bubble = bubbleNode(at: point),
              let feedback = feedbackByID[bubble.feedbackID] else { return }

        if containsNode(named: "feedback-author", at: point),
           feedback.senderID != nil {
            if !reduceMotion {
                bubble.playPoyon()
            }
            onSelectAuthor?(feedback)
            return
        }

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
        (contact.bodyA.node as? PhysicsCompanionNode)?.playPoyon()
        (contact.bodyB.node as? PhysicsCompanionNode)?.playPoyon()
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

    private func companionNode(at point: CGPoint) -> PhysicsCompanionNode? {
        for hitNode in nodes(at: point) {
            var currentNode: SKNode? = hitNode
            while let node = currentNode {
                if let companion = node as? PhysicsCompanionNode {
                    return companion
                }
                currentNode = node.parent
            }
        }
        return nil
    }

    private func containsNode(named name: String, at point: CGPoint) -> Bool {
        for hitNode in nodes(at: point) {
            var currentNode: SKNode? = hitNode
            while let node = currentNode {
                if node.name == name { return true }
                currentNode = node.parent
            }
        }
        return false
    }

    private func rebuild(feedbacks: [Feedback], layout: BubbleFieldLayout) {
        removeAllChildren()
        feedbackByID = Dictionary(uniqueKeysWithValues: feedbacks.map { ($0.id, $0) })
        oldestFeedbacks = Array(feedbacks.reversed())
        placementByID = Dictionary(
            uniqueKeysWithValues: layout.placements.map { ($0.feedbackID, $0) }
        )
        activeBubbleNodes.removeAll(keepingCapacity: true)
        activeCompanionNodes.removeAll(keepingCapacity: true)
        addPhysicsBoundaries(to: self, height: worldHeight)

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

        let visibleMinimumY = cameraNode.position.y - size.height / 2 - BubblePhysicsMetrics.rowSpacing * 2
        let visibleMaximumY = cameraNode.position.y + size.height / 2 + BubblePhysicsMetrics.rowSpacing * 2
        let visibleFeedbacks = oldestFeedbacks.filter { feedback in
            guard let placement = placementByID[feedback.id] else { return false }
            return placement.position.y >= visibleMinimumY
                && placement.position.y <= visibleMaximumY
        }
        let visibleIDs = Set(visibleFeedbacks.map(\.id))

        let idsToRemove = activeBubbleNodes.keys.filter { !visibleIDs.contains($0) }
        for id in idsToRemove {
            activeBubbleNodes[id]?.removeFromParent()
            activeBubbleNodes[id] = nil
            activeCompanionNodes[id]?.removeFromParent()
            activeCompanionNodes[id] = nil
        }

        for feedback in visibleFeedbacks {
            guard activeBubbleNodes[feedback.id] == nil,
                  let placement = placementByID[feedback.id] else { continue }
            let node = PhysicsBubbleNode(
                feedback: feedback,
                size: placement.size,
                highlighted: highlightedFeedbackIDs.contains(feedback.id)
            )

            node.position = placement.position
            node.zRotation = reduceMotion ? 0 : placement.rotation
            node.physicsBody?.isDynamic = !reduceMotion
            addChild(node)
            activeBubbleNodes[feedback.id] = node

            let companionHeight = CompanionPhysicsMetrics.height(for: placement.size)
            let companion = PhysicsCompanionNode(
                feedback: feedback,
                height: companionHeight
            )
            let direction: CGFloat = stableUnit(feedback.id, salt: 71) < 0.5 ? -1 : 1
            let proposedX = placement.position.x
                + direction * (placement.size.width * 0.43 + companion.visualSize.width * 0.25)
            companion.position = CGPoint(
                x: min(
                    max(proposedX, companion.visualSize.width * 0.42 + 5),
                    size.width - companion.visualSize.width * 0.42 - 5
                ),
                y: placement.position.y
                    + (stableUnit(feedback.id, salt: 73) - 0.5) * placement.size.height * 0.36
            )
            companion.physicsBody?.isDynamic = !reduceMotion
            companion.zPosition = 6
            addChild(companion)
            activeCompanionNodes[feedback.id] = companion
        }
    }

}

@MainActor
final class BubbleDropPhysicsScene: SKScene, SKPhysicsContactDelegate {
    private var configurationKey: ConfigurationKey?
    private var pendingNode: PhysicsBubbleNode?
    private var pendingFeedback: Feedback?
    private var pendingHasLanded = false
    private var isDraggingPending = false
    private var touchStart: CGPoint?
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
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)
        touchStart = point
        guard
              let pendingNode,
              pendingNode.physicsBody?.isDynamic == false else { return }
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
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)
        defer { touchStart = nil }

        if isDraggingPending {
            releasePendingBubble()
            return
        }

        if let touchStart,
           hypot(point.x - touchStart.x, point.y - touchStart.y) <= 14,
           let companion = companionNode(at: point),
           !reduceMotion {
            companion.playPoyon()
            companion.physicsBody?.applyImpulse(CGVector(dx: 0, dy: 0.10))
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        isDraggingPending = false
        touchStart = nil
    }

    func didBegin(_ contact: SKPhysicsContact) {
        let bubbleA = contact.bodyA.node as? PhysicsBubbleNode
        let bubbleB = contact.bodyB.node as? PhysicsBubbleNode

        if !reduceMotion {
            bubbleA?.playPoyon()
            bubbleB?.playPoyon()
            (contact.bodyA.node as? PhysicsCompanionNode)?.playPoyon()
            (contact.bodyB.node as? PhysicsCompanionNode)?.playPoyon()
        }

        guard !pendingHasLanded,
              let pendingNode,
              pendingNode.physicsBody?.isDynamic == true,
              bubbleA === pendingNode || bubbleB === pendingNode else { return }

        let otherBody = bubbleA === pendingNode ? contact.bodyB : contact.bodyA
        let landedCategory = PhysicsCategory.bubble | PhysicsCategory.floor
        guard otherBody.categoryBitMask & landedCategory != 0 else { return }

        pendingHasLanded = true
        spawnCompanion(for: pendingNode)
        onLanded?()
    }

    private func rebuild(feedback: Feedback, existingFeedbacks: [Feedback]) {
        removeAllChildren()
        pendingFeedback = feedback
        pendingHasLanded = false
        isDraggingPending = false
        touchStart = nil
        addPhysicsBoundaries(to: self)

        var settledBubbles: [(position: CGPoint, size: CGSize)] = []

        for existingFeedback in existingFeedbacks.reversed() {
            let existingSize = BubblePhysicsMetrics.dropExistingBubbleSize(
                for: existingFeedback,
                width: size.width
            )
            let halfWidth = existingSize.width * 0.48
            let minimumX = halfWidth + 6
            let maximumX = max(minimumX, size.width - halfWidth - 6)
            let seed = stableSeed(existingFeedback.id)
            let x = minimumX
                + stableUnit(existingFeedback.id, salt: 3) * (maximumX - minimumX)
            var y = 18 + existingSize.height / 2
            for settled in settledBubbles {
                let horizontalClearance = (existingSize.width + settled.size.width) * 0.39
                guard abs(x - settled.position.x) < horizontalClearance else { continue }
                y = max(
                    y,
                    settled.position.y + (existingSize.height + settled.size.height) * 0.42
                )
            }

            let node = PhysicsBubbleNode(feedback: existingFeedback, size: existingSize)
            node.position = CGPoint(x: x, y: y)
            node.zRotation = reduceMotion ? 0 : CGFloat((seed % 7) - 3) * .pi / 180
            node.physicsBody?.isDynamic = !reduceMotion
            addChild(node)

            let companion = PhysicsCompanionNode(
                feedback: existingFeedback,
                height: CompanionPhysicsMetrics.height(for: existingSize)
            )
            let direction: CGFloat = stableUnit(existingFeedback.id, salt: 81) < 0.5 ? -1 : 1
            companion.position = CGPoint(
                x: min(
                    max(
                        x + direction * existingSize.width * 0.42,
                        companion.visualSize.width * 0.42 + 5
                    ),
                    size.width - companion.visualSize.width * 0.42 - 5
                ),
                y: y + existingSize.height * 0.10
            )
            companion.physicsBody?.isDynamic = !reduceMotion
            companion.zPosition = 6
            addChild(companion)
            settledBubbles.append((node.position, existingSize))
        }

        let pendingSize = BubblePhysicsMetrics.pendingBubbleSize(
            for: feedback,
            width: size.width
        )
        let pending = PhysicsBubbleNode(feedback: feedback, size: pendingSize)
        pending.position = CGPoint(
            x: size.width / 2,
            y: size.height - pendingSize.height / 2 - 6
        )
        pending.zPosition = 200
        pending.physicsBody?.isDynamic = false
        pending.physicsBody?.affectedByGravity = false
        pending.physicsBody?.contactTestBitMask = PhysicsCategory.bubble | PhysicsCategory.floor
        addChild(pending)
        pendingNode = pending
    }

    private func spawnCompanion(for bubble: PhysicsBubbleNode) {
        guard let pendingFeedback else { return }

        let companion = PhysicsCompanionNode(
            feedback: pendingFeedback,
            height: CompanionPhysicsMetrics.height(for: bubble.visualSize) * 1.08
        )
        let hasSpaceOnRight = bubble.position.x + bubble.visualSize.width * 0.65 < size.width
        let direction: CGFloat = hasSpaceOnRight ? 1 : -1
        companion.position = CGPoint(
            x: min(
                max(
                    bubble.position.x + direction * bubble.visualSize.width * 0.46,
                    companion.visualSize.width * 0.42 + 5
                ),
                size.width - companion.visualSize.width * 0.42 - 5
            ),
            y: bubble.position.y + bubble.visualSize.height * 0.12
        )
        companion.zPosition = 220
        companion.physicsBody?.isDynamic = !reduceMotion
        addChild(companion)
        companion.playSpawn(reduceMotion: reduceMotion, horizontalDirection: direction)
    }

    private func companionNode(at point: CGPoint) -> PhysicsCompanionNode? {
        for hitNode in nodes(at: point) {
            var currentNode: SKNode? = hitNode
            while let node = currentNode {
                if let companion = node as? PhysicsCompanionNode {
                    return companion
                }
                currentNode = node.parent
            }
        }
        return nil
    }
}
