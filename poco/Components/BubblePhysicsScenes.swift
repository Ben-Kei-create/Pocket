@preconcurrency import SpriteKit
import UIKit

@MainActor
final class BubbleWallPhysicsScene: SKScene, @preconcurrency SKPhysicsContactDelegate {
    private var configurationKey: ConfigurationKey?
    private var feedbackByID: [UUID: Feedback] = [:]
    private var oldestFeedbacks: [Feedback] = []
    private var placementByID: [UUID: BubbleFieldPlacement] = [:]
    private var activeBubbleNodes: [UUID: PhysicsBubbleNode] = [:]
    private var activeCompanionNodes: [UUID: PhysicsCompanionNode] = [:]
    private var highlightedFeedbackIDs: Set<UUID> = []
    private var resolvedMergeKeys: Set<String> = []
    private var consumedCompanionFeedbackIDs: Set<UUID> = []
    private var onSelect: ((Feedback) -> Void)?
    private var onCompanionTapped: ((String) -> Void)?
    private var onRareCompanionBorn: ((String) -> Void)?
    private var onRareCompanionTapped: ((String) -> Void)?
    private var touchStart: CGPoint?
    private var reduceMotion = false
    private var enablesCompanionEvolution = false
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
        enablesCompanionEvolution: Bool,
        highlightedFeedbackIDs: Set<UUID>,
        onSelect: ((Feedback) -> Void)?,
        onCompanionTapped: ((String) -> Void)?,
        onRareCompanionBorn: ((String) -> Void)?,
        onRareCompanionTapped: ((String) -> Void)?
    ) {
        self.onSelect = onSelect
        self.onCompanionTapped = onCompanionTapped
        self.onRareCompanionBorn = onRareCompanionBorn
        self.onRareCompanionTapped = onRareCompanionTapped
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
            enablesCompanionEvolution: enablesCompanionEvolution,
            reduceMotion: reduceMotion
        )
        guard key != configurationKey, size.width > 0, size.height > 0 else { return }

        configurationKey = key
        self.reduceMotion = reduceMotion
        self.enablesCompanionEvolution = enablesCompanionEvolution
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

        if let rareCompanion = rareCompanionNode(at: point) {
            if !reduceMotion {
                rareCompanion.playPoyon()
            }
            if rareCompanion.claimTapReward() {
                onRareCompanionTapped?("rare-tap:\(rareCompanion.eventKey)")
            }
            return
        }

        if let companion = companionNode(at: point) {
            if !reduceMotion {
                companion.playPoyon()
            }
            if companion.claimTapReward() {
                onCompanionTapped?("companion-tap:\(companion.feedbackID.uuidString)")
            }
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
        (contact.bodyA.node as? PhysicsCompanionNode)?.settleAfterContact()
        (contact.bodyB.node as? PhysicsCompanionNode)?.settleAfterContact()
        (contact.bodyA.node as? PhysicsRareCompanionNode)?.settleAfterContact()
        (contact.bodyB.node as? PhysicsRareCompanionNode)?.settleAfterContact()

        if !reduceMotion {
            (contact.bodyA.node as? PhysicsBubbleNode)?.playPoyon()
            (contact.bodyB.node as? PhysicsBubbleNode)?.playPoyon()
            (contact.bodyA.node as? PhysicsCompanionNode)?.playPoyon()
            (contact.bodyB.node as? PhysicsCompanionNode)?.playPoyon()
            (contact.bodyA.node as? PhysicsRareCompanionNode)?.playPoyon()
            (contact.bodyB.node as? PhysicsRareCompanionNode)?.playPoyon()
        }

        if let first = contact.bodyA.node as? PhysicsCompanionNode,
           let second = contact.bodyB.node as? PhysicsCompanionNode {
            resolveMerge(first, second, at: contact.contactPoint)
        }
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

    private func rareCompanionNode(at point: CGPoint) -> PhysicsRareCompanionNode? {
        for hitNode in nodes(at: point) {
            var currentNode: SKNode? = hitNode
            while let node = currentNode {
                if let companion = node as? PhysicsRareCompanionNode {
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
                highlighted: highlightedFeedbackIDs.contains(feedback.id),
                rotationEnabled: !reduceMotion
            )

            node.position = placement.position
            node.zRotation = reduceMotion ? 0 : placement.rotation
            node.physicsBody?.isDynamic = !reduceMotion
            addChild(node)
            activeBubbleNodes[feedback.id] = node

            if PocoCompanion.shouldAppear(for: feedback),
               !consumedCompanionFeedbackIDs.contains(feedback.id) {
                let companionHeight = CompanionPhysicsMetrics.height(for: placement.size)
                let companion = PhysicsCompanionNode(
                    feedback: feedback,
                    height: companionHeight
                )
                let direction: CGFloat = stableUnit(feedback.id, salt: 71) < 0.5 ? -1 : 1
                let proposedX = placement.position.x
                    + direction * (placement.size.width * 0.40 + companion.visualSize.width * 0.12)
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
                if enablesCompanionEvolution && !reduceMotion {
                    let horizontal = (stableUnit(feedback.id, salt: 79) - 0.5) * 0.08
                    companion.physicsBody?.applyImpulse(CGVector(dx: horizontal, dy: 0.03))
                }
            }
        }
    }

    private func resolveMerge(
        _ first: PhysicsCompanionNode,
        _ second: PhysicsCompanionNode,
        at point: CGPoint
    ) {
        guard enablesCompanionEvolution,
              first !== second,
              first.avatar == second.avatar else { return }

        let mergeKey = CompanionEvolution.mergeKey(first.feedbackID, second.feedbackID)
        guard !resolvedMergeKeys.contains(mergeKey),
              !first.isResolvingMerge,
              !second.isResolvingMerge,
              first.beginMerge(),
              second.beginMerge() else { return }

        resolvedMergeKeys.insert(mergeKey)
        consumedCompanionFeedbackIDs.insert(first.feedbackID)
        consumedCompanionFeedbackIDs.insert(second.feedbackID)
        activeCompanionNodes[first.feedbackID] = nil
        activeCompanionNodes[second.feedbackID] = nil
        first.playMergeAndRemove(reduceMotion: reduceMotion) {}
        second.playMergeAndRemove(reduceMotion: reduceMotion) {}

        guard CompanionEvolution.shouldBirth(eventKey: mergeKey) else { return }
        let delay = reduceMotion ? 0.0 : 0.19
        run(.sequence([
            .wait(forDuration: delay),
            .run { [weak self] in
                self?.spawnRareCompanion(
                    from: first.avatar,
                    eventKey: mergeKey,
                    height: max(first.visualSize.height, second.visualSize.height),
                    at: point
                )
            }
        ]))
    }

    private func spawnRareCompanion(
        from avatar: BuiltInAvatar,
        eventKey: String,
        height: CGFloat,
        at point: CGPoint
    ) {
        let kind = RareCompanionKind.born(from: avatar, eventKey: eventKey)
        let node = PhysicsRareCompanionNode(kind: kind, eventKey: eventKey, height: height)
        let verticalInset = node.visualSize.height * 0.44
        node.position = CGPoint(
            x: min(max(point.x, node.visualSize.width * 0.4), size.width - node.visualSize.width * 0.4),
            y: min(max(point.y, verticalInset), worldHeight - verticalInset)
        )
        node.zPosition = 12
        node.physicsBody?.isDynamic = !reduceMotion
        addChild(node)
        node.playBirth(reduceMotion: reduceMotion)
        onRareCompanionBorn?("rare-birth:\(eventKey)")
    }

}

@MainActor
final class BubbleDropPhysicsScene: SKScene, @preconcurrency SKPhysicsContactDelegate {
    private var configurationKey: ConfigurationKey?
    private var feedbackByID: [UUID: Feedback] = [:]
    private var pendingNode: PhysicsBubbleNode?
    private var pendingFeedback: Feedback?
    private var pendingHasLanded = false
    private var isDraggingPending = false
    private var isScrollEnabled = false
    private var touchStart: CGPoint?
    private var reduceMotion = false
    private var worldHeight: CGFloat = 0
    private var onLanded: (() -> Void)?
    private var onSelect: ((Feedback) -> Void)?
    private var onCompanionTapped: ((String) -> Void)?
    private var onRareCompanionBorn: ((String) -> Void)?
    private var onRareCompanionTapped: ((String) -> Void)?
    private var resolvedMergeKeys: Set<String> = []
    private var consumedCompanionFeedbackIDs: Set<UUID> = []
    private var enablesCompanionEvolution = false
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
        feedback: Feedback,
        existingFeedbacks: [Feedback],
        size: CGSize,
        reduceMotion: Bool,
        enablesCompanionEvolution: Bool,
        onLanded: @escaping () -> Void,
        onSelect: ((Feedback) -> Void)?,
        onCompanionTapped: ((String) -> Void)?,
        onRareCompanionBorn: ((String) -> Void)?,
        onRareCompanionTapped: ((String) -> Void)?
    ) {
        self.onLanded = onLanded
        self.onSelect = onSelect
        self.onCompanionTapped = onCompanionTapped
        self.onRareCompanionBorn = onRareCompanionBorn
        self.onRareCompanionTapped = onRareCompanionTapped
        let layout = BubbleFieldLayout.make(
            feedbacks: existingFeedbacks,
            availableWidth: size.width
        )
        let dropZoneHeight = max(300, size.height * 0.58)
        let worldHeight = max(size.height, layout.contentHeight + dropZoneHeight)
        let key = ConfigurationKey(
            ids: existingFeedbacks.map(\.id) + [feedback.id],
            width: Int(size.width.rounded()),
            height: Int(size.height.rounded()),
            worldHeight: Int(worldHeight.rounded()),
            enablesCompanionEvolution: enablesCompanionEvolution,
            reduceMotion: reduceMotion
        )
        guard key != configurationKey, size.width > 0, size.height > 0 else { return }

        configurationKey = key
        self.reduceMotion = reduceMotion
        self.enablesCompanionEvolution = enablesCompanionEvolution
        self.size = size
        self.worldHeight = worldHeight
        physicsWorld.gravity = CGVector(dx: 0, dy: reduceMotion ? -9 : -3.2)
        rebuild(
            feedback: feedback,
            existingFeedbacks: existingFeedbacks,
            layout: layout
        )
    }

    func setScrollEnabled(_ isEnabled: Bool) {
        isScrollEnabled = isEnabled
    }

    func scrollBy(_ distance: CGFloat) {
        guard isScrollEnabled, worldHeight > size.height else { return }
        let minimumY = size.height / 2
        let maximumY = worldHeight - size.height / 2
        cameraNode.position.y = min(
            max(cameraNode.position.y + distance, minimumY),
            maximumY
        )
    }

    func releasePendingBubble() {
        guard let pendingNode, pendingNode.physicsBody?.isDynamic == false else { return }
        isDraggingPending = false
        pendingNode.prepareForDrop(in: size.width)
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
            y: min(max(point.y, worldHeight - 132), worldHeight - 55)
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

        guard let touchStart,
              hypot(point.x - touchStart.x, point.y - touchStart.y) <= 14 else { return }

        if let rareCompanion = rareCompanionNode(at: point) {
            if !reduceMotion {
                rareCompanion.playPoyon()
            }
            if rareCompanion.claimTapReward() {
                onRareCompanionTapped?("rare-tap:\(rareCompanion.eventKey)")
            }
            return
        }

        if let companion = companionNode(at: point) {
            if !reduceMotion {
                companion.playPoyon()
            }
            if companion.claimTapReward() {
                onCompanionTapped?("companion-tap:\(companion.feedbackID.uuidString)")
            }
            return
        }

        if pendingHasLanded,
           let bubble = bubbleNode(at: point),
           let selectedFeedback = feedbackByID[bubble.feedbackID] {
            if !reduceMotion {
                bubble.playPoyon()
            }
            onSelect?(selectedFeedback)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        isDraggingPending = false
        touchStart = nil
    }

    func didBegin(_ contact: SKPhysicsContact) {
        let bubbleA = contact.bodyA.node as? PhysicsBubbleNode
        let bubbleB = contact.bodyB.node as? PhysicsBubbleNode

        (contact.bodyA.node as? PhysicsCompanionNode)?.settleAfterContact()
        (contact.bodyB.node as? PhysicsCompanionNode)?.settleAfterContact()
        (contact.bodyA.node as? PhysicsRareCompanionNode)?.settleAfterContact()
        (contact.bodyB.node as? PhysicsRareCompanionNode)?.settleAfterContact()

        if !reduceMotion {
            bubbleA?.playPoyon()
            bubbleB?.playPoyon()
            (contact.bodyA.node as? PhysicsCompanionNode)?.playPoyon()
            (contact.bodyB.node as? PhysicsCompanionNode)?.playPoyon()
            (contact.bodyA.node as? PhysicsRareCompanionNode)?.playPoyon()
            (contact.bodyB.node as? PhysicsRareCompanionNode)?.playPoyon()
        }

        if let first = contact.bodyA.node as? PhysicsCompanionNode,
           let second = contact.bodyB.node as? PhysicsCompanionNode {
            resolveMerge(first, second, at: contact.contactPoint)
        }

        guard !pendingHasLanded,
              let pendingNode,
              pendingNode.physicsBody?.isDynamic == true,
              bubbleA === pendingNode || bubbleB === pendingNode else { return }

        let otherBody = bubbleA === pendingNode ? contact.bodyB : contact.bodyA
        let landedCategory = PhysicsCategory.bubble | PhysicsCategory.floor
        guard otherBody.categoryBitMask & landedCategory != 0 else { return }

        pendingHasLanded = true
        if !reduceMotion {
            pendingNode.addLandingRock()
        }
        spawnCompanion(for: pendingNode)
        onLanded?()
    }

    private func rebuild(
        feedback: Feedback,
        existingFeedbacks: [Feedback],
        layout: BubbleFieldLayout
    ) {
        removeAllChildren()
        feedbackByID = Dictionary(
            uniqueKeysWithValues: (existingFeedbacks + [feedback]).map { ($0.id, $0) }
        )
        pendingFeedback = feedback
        pendingHasLanded = false
        isScrollEnabled = false
        isDraggingPending = false
        touchStart = nil
        addPhysicsBoundaries(to: self, height: worldHeight)

        let placementByID = Dictionary(
            uniqueKeysWithValues: layout.placements.map { ($0.feedbackID, $0) }
        )
        for existingFeedback in existingFeedbacks.reversed() {
            guard let placement = placementByID[existingFeedback.id] else { continue }
            let node = PhysicsBubbleNode(
                feedback: existingFeedback,
                size: placement.size,
                rotationEnabled: !reduceMotion
            )
            node.position = placement.position
            node.zRotation = reduceMotion ? 0 : placement.rotation
            node.physicsBody?.isDynamic = !reduceMotion
            addChild(node)

            if PocoCompanion.shouldAppear(for: existingFeedback),
               !consumedCompanionFeedbackIDs.contains(existingFeedback.id) {
                let companion = PhysicsCompanionNode(
                    feedback: existingFeedback,
                    height: CompanionPhysicsMetrics.height(for: placement.size)
                )
                let direction: CGFloat = stableUnit(existingFeedback.id, salt: 81) < 0.5 ? -1 : 1
                companion.position = CGPoint(
                    x: min(
                        max(
                            placement.position.x + direction * placement.size.width * 0.39,
                            companion.visualSize.width * 0.42 + 5
                        ),
                        size.width - companion.visualSize.width * 0.42 - 5
                    ),
                    y: placement.position.y + placement.size.height * 0.10
                )
                companion.physicsBody?.isDynamic = !reduceMotion
                companion.zPosition = 6
                addChild(companion)
            }
        }

        let pendingSize = BubblePhysicsMetrics.pendingBubbleSize(
            for: feedback,
            width: size.width
        )
        let pending = PhysicsBubbleNode(
            feedback: feedback,
            size: pendingSize,
            rotationEnabled: !reduceMotion
        )
        pending.position = CGPoint(
            x: size.width / 2,
            y: worldHeight - pendingSize.height / 2 - 10
        )
        pending.zPosition = 200
        pending.physicsBody?.isDynamic = false
        pending.physicsBody?.affectedByGravity = false
        pending.physicsBody?.contactTestBitMask = PhysicsCategory.bubble | PhysicsCategory.floor
        addChild(pending)
        pendingNode = pending

        cameraNode.position = CGPoint(
            x: size.width / 2,
            y: worldHeight - size.height / 2
        )
        addChild(cameraNode)
        camera = cameraNode
    }

    private func spawnCompanion(for bubble: PhysicsBubbleNode) {
        guard let pendingFeedback,
              PocoCompanion.shouldAppear(for: pendingFeedback) else { return }

        let companion = PhysicsCompanionNode(
            feedback: pendingFeedback,
            height: CompanionPhysicsMetrics.height(for: bubble.visualSize)
        )
        let hasSpaceOnRight = bubble.position.x + bubble.visualSize.width * 0.65 < size.width
        let direction: CGFloat = hasSpaceOnRight ? 1 : -1
        companion.position = CGPoint(
            x: min(
                max(
                    bubble.position.x + direction * bubble.visualSize.width * 0.40,
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

    private func rareCompanionNode(at point: CGPoint) -> PhysicsRareCompanionNode? {
        for hitNode in nodes(at: point) {
            var currentNode: SKNode? = hitNode
            while let node = currentNode {
                if let companion = node as? PhysicsRareCompanionNode {
                    return companion
                }
                currentNode = node.parent
            }
        }
        return nil
    }

    private func resolveMerge(
        _ first: PhysicsCompanionNode,
        _ second: PhysicsCompanionNode,
        at point: CGPoint
    ) {
        guard enablesCompanionEvolution,
              first !== second,
              first.avatar == second.avatar else { return }

        let mergeKey = CompanionEvolution.mergeKey(first.feedbackID, second.feedbackID)
        guard !resolvedMergeKeys.contains(mergeKey),
              !first.isResolvingMerge,
              !second.isResolvingMerge,
              first.beginMerge(),
              second.beginMerge() else { return }

        resolvedMergeKeys.insert(mergeKey)
        consumedCompanionFeedbackIDs.insert(first.feedbackID)
        consumedCompanionFeedbackIDs.insert(second.feedbackID)
        first.playMergeAndRemove(reduceMotion: reduceMotion) {}
        second.playMergeAndRemove(reduceMotion: reduceMotion) {}

        guard CompanionEvolution.shouldBirth(eventKey: mergeKey) else { return }
        let delay = reduceMotion ? 0.0 : 0.19
        run(.sequence([
            .wait(forDuration: delay),
            .run { [weak self] in
                self?.spawnRareCompanion(
                    from: first.avatar,
                    eventKey: mergeKey,
                    height: max(first.visualSize.height, second.visualSize.height),
                    at: point
                )
            }
        ]))
    }

    private func spawnRareCompanion(
        from avatar: BuiltInAvatar,
        eventKey: String,
        height: CGFloat,
        at point: CGPoint
    ) {
        let kind = RareCompanionKind.born(from: avatar, eventKey: eventKey)
        let node = PhysicsRareCompanionNode(kind: kind, eventKey: eventKey, height: height)
        let verticalInset = node.visualSize.height * 0.44
        node.position = CGPoint(
            x: min(max(point.x, node.visualSize.width * 0.4), size.width - node.visualSize.width * 0.4),
            y: min(max(point.y, verticalInset), worldHeight - verticalInset)
        )
        node.zPosition = 230
        node.physicsBody?.isDynamic = !reduceMotion
        addChild(node)
        node.playBirth(reduceMotion: reduceMotion)
        onRareCompanionBorn?("rare-birth:\(eventKey)")
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
}
