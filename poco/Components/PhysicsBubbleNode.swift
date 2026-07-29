import SpriteKit
import SwiftUI
import UIKit

@MainActor
final class PhysicsBubbleNode: SKNode {
    private static let sharedBubbleTexture: SKTexture = {
        let texture = SKTexture(imageNamed: BubbleArtworkStyle.active.textureAssetName)
        texture.filteringMode = .linear
        return texture
    }()

    let feedbackID: UUID
    let visualSize: CGSize

    private let visualContainer = SKNode()

    init(
        feedback: Feedback,
        size: CGSize,
        highlighted: Bool = false,
        rotationEnabled: Bool = true
    ) {
        feedbackID = feedback.id
        visualSize = size
        super.init()

        name = "feedback-\(feedback.id.uuidString)"
        addChild(visualContainer)
        addBubbleArtwork(feedback: feedback, size: size, highlighted: highlighted)

        physicsBody = BubblePhysicsBody.make(size: size)
        physicsBody?.categoryBitMask = PhysicsCategory.bubble
        physicsBody?.collisionBitMask = PhysicsCategory.bubble
            | PhysicsCategory.companion
            | PhysicsCategory.floor
            | PhysicsCategory.wall
        physicsBody?.contactTestBitMask = PhysicsCategory.bubble
        physicsBody?.restitution = 0.22
        physicsBody?.friction = 0.78
        physicsBody?.linearDamping = 0.68
        physicsBody?.angularDamping = 0.72
        let relativeArea = (size.width * size.height) / (116 * 60)
        physicsBody?.mass = min(0.28, max(0.14, 0.18 * relativeArea))
        physicsBody?.allowsRotation = rotationEnabled
        if rotationEnabled {
            let maximumTilt = CGFloat.pi / 15
            constraints = [
                SKConstraint.zRotation(
                    SKRange(lowerLimit: -maximumTilt, upperLimit: maximumTilt)
                )
            ]
        }
    }

    required init?(coder aDecoder: NSCoder) {
        nil
    }

    func prepareForDrop(in sceneWidth: CGFloat) {
        guard physicsBody?.allowsRotation == true else { return }
        let horizontalOffset = position.x - sceneWidth / 2
        let direction: CGFloat
        if abs(horizontalOffset) > 10 {
            direction = horizontalOffset < 0 ? -1 : 1
        } else {
            direction = stableUnit(feedbackID, salt: 113) < 0.5 ? -1 : 1
        }
        zRotation = direction * .pi / 90
        physicsBody?.angularVelocity = direction * 0.20
    }

    func addLandingRock() {
        guard let physicsBody, physicsBody.allowsRotation else { return }
        let fallbackDirection: CGFloat = stableUnit(feedbackID, salt: 127) < 0.5 ? -1 : 1
        let direction: CGFloat = abs(physicsBody.angularVelocity) > 0.02
            ? (physicsBody.angularVelocity < 0 ? -1 : 1)
            : fallbackDirection
        physicsBody.angularVelocity += direction * 0.38
    }

    func playPoyon() {
        guard visualContainer.action(forKey: "poyon") == nil else { return }
        let action = SKAction.sequence([
            .group([
                .scaleX(to: 1.055, duration: 0.07),
                .scaleY(to: 0.93, duration: 0.07)
            ]),
            .group([
                .scaleX(to: 0.975, duration: 0.08),
                .scaleY(to: 1.035, duration: 0.08)
            ]),
            .scale(to: 1, duration: 0.10)
        ])
        action.timingMode = .easeInEaseOut
        visualContainer.run(action, withKey: "poyon")
    }

    private func addBubbleArtwork(feedback: Feedback, size: CGSize, highlighted: Bool) {
        let bubbleSprite = SKSpriteNode(texture: Self.sharedBubbleTexture)
        bubbleSprite.size = size
        bubbleSprite.color = UIColor(PocoTheme.bubble(feedback.bubbleColor))
        bubbleSprite.colorBlendFactor = 0.70
        bubbleSprite.zPosition = 0
        visualContainer.addChild(bubbleSprite)

        if highlighted {
            addOwnerHighlight(size: size)
        }
        if feedback.creatorReceivedAt != nil {
            addCreatorReceipt(size: size)
        }

        let tier = BubbleSizeTier(message: feedback.message)
        let fontSize: CGFloat = switch tier {
        case .small: 9.2
        case .medium: 9.8
        case .large: 10.4
        }
        let messageFont = PocoTypography.uiFont(size: fontSize, weight: .medium)
        let lines = wrappedLines(
            feedback.message,
            font: messageFont,
            maximumWidth: size.width * 0.74,
            maximumLines: tier == .large ? 3 : 2
        )
        let lineHeight = fontSize + 2
        let firstLineY: CGFloat = switch lines.count {
        case 1: 9
        case 2: 15
        default: 20
        }
        let leadingX = -size.width * 0.37

        for (index, line) in lines.enumerated() {
            let label = makeLabel(
                text: line,
                font: messageFont,
                color: UIColor.label.withAlphaComponent(0.86)
            )
            label.horizontalAlignmentMode = .left
            label.position = CGPoint(
                x: leadingX,
                y: CGFloat(firstLineY) - CGFloat(index) * lineHeight
            )
            label.zPosition = 2
            visualContainer.addChild(label)
        }

        let authorY = -size.height * 0.24
        let avatarRadius: CGFloat = tier == .large ? 8 : 7
        let avatar = SKNode()
        avatar.name = "feedback-author"
        avatar.position = CGPoint(x: leadingX + avatarRadius, y: authorY)
        avatar.zPosition = 2
        visualContainer.addChild(avatar)

        let avatarBackground = SKShapeNode(circleOfRadius: avatarRadius)
        avatarBackground.fillColor = UIColor.black.withAlphaComponent(0.22)
        avatarBackground.strokeColor = .clear
        avatar.addChild(avatarBackground)

        let initial = makeLabel(
            text: String(feedback.nickname.prefix(1)),
            font: PocoTypography.uiFont(
                size: tier == .large ? 7.2 : 6.5,
                weight: .bold
            ),
            color: .white
        )
        initial.verticalAlignmentMode = .center
        initial.position = .zero
        avatar.addChild(initial)

        let avatarDiameter = avatarRadius * 2
        if let avatarName = feedback.senderAvatarName,
           BuiltInAvatar(rawValue: avatarName) != nil,
           let image = UIImage(named: avatarName) {
            addAvatarImage(image, to: avatar, diameter: avatarDiameter)
        } else if let avatarURL = feedback.senderAvatarURL {
            loadRemoteAvatar(avatarURL, into: avatar, diameter: avatarDiameter)
        }

        let nickname = makeLabel(
            text: feedback.nickname,
            font: PocoTypography.uiFont(
                size: tier == .large ? 9 : 8,
                weight: .medium
            ),
            color: UIColor.secondaryLabel.withAlphaComponent(0.86)
        )
        nickname.horizontalAlignmentMode = .left
        nickname.name = "feedback-author"
        nickname.position = CGPoint(x: leadingX + avatarRadius * 2 + 5, y: authorY)
        nickname.zPosition = 2
        visualContainer.addChild(nickname)

        let authorHitTarget = SKShapeNode(
            rectOf: CGSize(width: size.width * 0.54, height: max(20, avatarRadius * 2 + 6)),
            cornerRadius: 10
        )
        authorHitTarget.name = "feedback-author"
        authorHitTarget.fillColor = UIColor.white.withAlphaComponent(0.001)
        authorHitTarget.strokeColor = .clear
        authorHitTarget.position = CGPoint(x: leadingX + size.width * 0.27, y: authorY)
        authorHitTarget.zPosition = 5
        visualContainer.addChild(authorHitTarget)
    }

    private func loadRemoteAvatar(_ url: URL, into container: SKNode, diameter: CGFloat) {
        Task { [weak self, weak container] in
            guard let data = await RemoteAvatarDataCache.shared.data(for: url),
                  let image = RemoteImageDecoder.decode(data, maximumPixelSize: 128),
                  let self,
                  let container,
                  container.parent != nil else { return }
            self.addAvatarImage(image, to: container, diameter: diameter)
        }
    }

    private func addAvatarImage(_ image: UIImage, to container: SKNode, diameter: CGFloat) {
        container.childNode(withName: "profile-avatar")?.removeFromParent()

        let crop = SKCropNode()
        crop.name = "profile-avatar"
        let mask = SKShapeNode(circleOfRadius: diameter / 2)
        mask.fillColor = .white
        mask.strokeColor = .clear
        crop.maskNode = mask

        let sprite = SKSpriteNode(texture: SKTexture(image: image))
        sprite.size = CGSize(width: diameter, height: diameter)
        crop.addChild(sprite)
        crop.zPosition = 3
        container.addChild(crop)
    }

    private func addOwnerHighlight(size: CGSize) {
        let outline = SKShapeNode(
            rectOf: CGSize(width: size.width + 5, height: size.height + 5),
            cornerRadius: size.height / 2
        )
        outline.fillColor = .clear
        outline.strokeColor = UIColor(PocoTheme.primary).withAlphaComponent(0.72)
        outline.lineWidth = 1.5
        outline.glowWidth = 3
        outline.zPosition = 1
        visualContainer.addChild(outline)

        let badgeSize = CGSize(width: 36, height: 15)
        let badge = SKShapeNode(rectOf: badgeSize, cornerRadius: badgeSize.height / 2)
        badge.fillColor = UIColor(PocoTheme.primary).withAlphaComponent(0.92)
        badge.strokeColor = .clear
        badge.position = CGPoint(x: size.width * 0.24, y: size.height * 0.29)
        badge.zPosition = 3
        visualContainer.addChild(badge)

        let label = makeLabel(
            text: "あなた",
            font: PocoTypography.uiFont(size: 7, weight: .bold),
            color: .white
        )
        label.position = .zero
        badge.addChild(label)
    }

    private func addCreatorReceipt(size: CGSize) {
        let mark = SKShapeNode(circleOfRadius: 9)
        mark.fillColor = UIColor(PocoTheme.primary).withAlphaComponent(0.96)
        mark.strokeColor = UIColor.white.withAlphaComponent(0.95)
        mark.lineWidth = 1.5
        mark.glowWidth = 2
        mark.position = CGPoint(x: size.width * 0.39, y: size.height * 0.31)
        mark.zPosition = 4
        visualContainer.addChild(mark)

        let symbol = makeLabel(
            text: "♥︎",
            font: .systemFont(ofSize: 10, weight: .bold),
            color: .white
        )
        symbol.position = .zero
        mark.addChild(symbol)
    }

    private func makeLabel(text: String, font: UIFont, color: UIColor) -> SKLabelNode {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]
        let label = SKLabelNode()
        label.attributedText = NSAttributedString(string: text, attributes: attributes)
        label.verticalAlignmentMode = .center
        return label
    }

    private func wrappedLines(
        _ text: String,
        font: UIFont,
        maximumWidth: CGFloat,
        maximumLines: Int
    ) -> [String] {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        var allLines: [String] = []
        var currentLine = ""

        for character in text {
            let candidate = currentLine + String(character)
            let width = (candidate as NSString).size(withAttributes: attributes).width
            if width > maximumWidth, !currentLine.isEmpty {
                allLines.append(currentLine)
                currentLine = String(character)
            } else {
                currentLine = candidate
            }
        }

        if !currentLine.isEmpty {
            allLines.append(currentLine)
        }
        guard allLines.count > maximumLines else { return allLines }

        var finalLine = allLines[maximumLines - 1]
        while !finalLine.isEmpty {
            let candidate = finalLine + "…"
            if (candidate as NSString).size(withAttributes: attributes).width <= maximumWidth {
                return Array(allLines.prefix(maximumLines - 1)) + [candidate]
            }
            finalLine.removeLast()
        }
        return Array(allLines.prefix(maximumLines - 1)) + ["…"]
    }
}

enum BubblePhysicsBody {
    static func make(size: CGSize) -> SKPhysicsBody {
        let radius = size.height * 0.42
        let horizontalOffset = max(0, size.width * 0.25)
        let bodies = [
            SKPhysicsBody(circleOfRadius: radius, center: CGPoint(x: -horizontalOffset, y: 2)),
            SKPhysicsBody(circleOfRadius: radius, center: CGPoint(x: 0, y: 2)),
            SKPhysicsBody(circleOfRadius: radius, center: CGPoint(x: horizontalOffset, y: 2))
        ]
        return SKPhysicsBody(bodies: bodies)
    }
}

enum BubblePhysicsMetrics {
    static let rowSpacing: CGFloat = 52
    static let wallBottomStartY: CGFloat = 46
    static let dropRowSpacing: CGFloat = 50
    static let dropPreviewLimit = 2

    static func wallBubbleSize(for feedback: Feedback, width: CGFloat) -> CGSize {
        let baseWidth = min(116, max(104, width * 0.29))
        switch BubbleSizeTier(message: feedback.message) {
        case .small:
            return CGSize(width: baseWidth * 0.82, height: 50)
        case .medium:
            return CGSize(width: baseWidth, height: 60)
        case .large:
            return CGSize(width: min(width * 0.40, baseWidth * 1.24), height: 72)
        }
    }

    static func dropExistingBubbleSize(for feedback: Feedback, width: CGFloat) -> CGSize {
        let baseWidth = min(112, max(102, width * 0.28))
        switch BubbleSizeTier(message: feedback.message) {
        case .small:
            return CGSize(width: baseWidth * 0.82, height: 48)
        case .medium:
            return CGSize(width: baseWidth, height: 58)
        case .large:
            return CGSize(width: min(width * 0.39, baseWidth * 1.24), height: 70)
        }
    }

    static func pendingBubbleSize(for feedback: Feedback, width: CGFloat) -> CGSize {
        switch BubbleSizeTier(message: feedback.message) {
        case .small:
            return CGSize(width: min(138, width * 0.40), height: 66)
        case .medium:
            return CGSize(width: min(164, width * 0.48), height: 78)
        case .large:
            return CGSize(width: min(190, width * 0.56), height: 92)
        }
    }
}

struct BubbleFieldPlacement: Equatable {
    let feedbackID: UUID
    let position: CGPoint
    let rotation: CGFloat
    let size: CGSize
}

struct BubbleFieldLayout: Equatable {
    let placements: [BubbleFieldPlacement]
    let contentHeight: CGFloat

    static func make(feedbacks: [Feedback], availableWidth: CGFloat) -> Self {
        guard availableWidth > 0, !feedbacks.isEmpty else {
            return BubbleFieldLayout(
                placements: [],
                contentHeight: BubblePhysicsMetrics.wallBottomStartY + 18
            )
        }

        var placements: [BubbleFieldPlacement] = []
        var collisionCandidates: [BubbleFieldPlacement] = []
        var highestEdge = BubblePhysicsMetrics.wallBottomStartY

        for feedback in feedbacks.reversed() {
            let bubbleSize = BubblePhysicsMetrics.wallBubbleSize(
                for: feedback,
                width: availableWidth
            )
            let halfWidth = bubbleSize.width * 0.48
            let minimumX = halfWidth + 4
            let maximumX = max(minimumX, availableWidth - halfWidth - 4)
            let lowerBand = max(
                BubblePhysicsMetrics.wallBottomStartY,
                highestEdge - bubbleSize.height * 0.72
            )
            // Placements far below the active band cannot raise this bubble.
            // Keeping only a generous nearby window avoids O(n²) layout work
            // when a project has hundreds of feedbacks.
            collisionCandidates.removeAll { existing in
                existing.position.y + existing.size.height < lowerBand - 120
            }
            var bestPosition = CGPoint(x: availableWidth / 2, y: lowerBand)
            var bestScore = CGFloat.greatestFiniteMagnitude

            for attempt in 0..<9 {
                let x = minimumX
                    + stableUnit(feedback.id, salt: attempt) * (maximumX - minimumX)
                var y = lowerBand

                for existing in collisionCandidates {
                    let deltaX = abs(x - existing.position.x)
                    let horizontalClearance = (bubbleSize.width + existing.size.width) * 0.44
                    guard deltaX < horizontalClearance else { continue }
                    let horizontalRatio = deltaX / horizontalClearance
                    let verticalClearance = (bubbleSize.height + existing.size.height) * 0.38
                    let requiredRise = verticalClearance
                        * sqrt(max(0, 1 - horizontalRatio * horizontalRatio))
                    y = max(y, existing.position.y + requiredRise)
                }

                let score = y + stableUnit(feedback.id, salt: attempt + 20) * 1.5
                if score < bestScore {
                    bestScore = score
                    bestPosition = CGPoint(x: x, y: y)
                }
            }

            let seed = stableSeed(feedback.id)
            let placement = BubbleFieldPlacement(
                feedbackID: feedback.id,
                position: bestPosition,
                rotation: CGFloat((seed % 11) - 5) * .pi / 180,
                size: bubbleSize
            )
            placements.append(placement)
            collisionCandidates.append(placement)
            highestEdge = max(highestEdge, bestPosition.y + bubbleSize.height / 2)
        }

        return BubbleFieldLayout(
            placements: placements,
            contentHeight: highestEdge + 34
        )
    }
}

enum PhysicsCategory {
    static let bubble: UInt32 = 1 << 0
    static let floor: UInt32 = 1 << 1
    static let wall: UInt32 = 1 << 2
    static let companion: UInt32 = 1 << 3
}

struct ConfigurationKey: Equatable {
    let ids: [UUID]
    var highlightedIDs: [UUID] = []
    var creatorReceivedIDs: [UUID] = []
    let width: Int
    let height: Int
    var worldHeight = 0
    var enablesCompanionEvolution = false
    let reduceMotion: Bool
}

@MainActor
func addPhysicsBoundaries(to scene: SKScene, height: CGFloat? = nil) {
    let inset: CGFloat = 3
    let floorY: CGFloat = 14
    let topY = max(floorY + 1, (height ?? scene.size.height) - 2)

    let floor = SKNode()
    floor.name = "field-floor"
    floor.physicsBody = SKPhysicsBody(
        edgeFrom: CGPoint(x: inset, y: floorY),
        to: CGPoint(x: scene.size.width - inset, y: floorY)
    )
    floor.physicsBody?.categoryBitMask = PhysicsCategory.floor
    floor.physicsBody?.collisionBitMask = PhysicsCategory.bubble | PhysicsCategory.companion
    floor.physicsBody?.contactTestBitMask = PhysicsCategory.bubble | PhysicsCategory.companion
    scene.addChild(floor)

    for (name, start, end) in [
        ("field-left", CGPoint(x: inset, y: floorY), CGPoint(x: inset, y: topY)),
        (
            "field-right",
            CGPoint(x: scene.size.width - inset, y: floorY),
            CGPoint(x: scene.size.width - inset, y: topY)
        ),
        (
            "field-top",
            CGPoint(x: inset, y: topY),
            CGPoint(x: scene.size.width - inset, y: topY)
        )
    ] {
        let wall = SKNode()
        wall.name = name
        wall.physicsBody = SKPhysicsBody(edgeFrom: start, to: end)
        wall.physicsBody?.categoryBitMask = PhysicsCategory.wall
        wall.physicsBody?.collisionBitMask = PhysicsCategory.bubble | PhysicsCategory.companion
        scene.addChild(wall)
    }
}

func stableSeed(_ id: UUID) -> Int {
    id.uuidString.unicodeScalars.reduce(0) { partial, scalar in
        (partial &* 31 &+ Int(scalar.value)) & 0x7fff_ffff
    }
}

func stableUnit(_ id: UUID, salt: Int) -> CGFloat {
    let seed = stableSeed(id)
    let mixed = (seed &* 1_103_515_245 &+ salt &* 12_345) & 0x7fff_ffff
    return CGFloat(mixed % 10_000) / 9_999
}
