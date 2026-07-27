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

    init(feedback: Feedback, size: CGSize) {
        feedbackID = feedback.id
        visualSize = size
        super.init()

        name = "feedback-\(feedback.id.uuidString)"
        addChild(visualContainer)
        addBubbleArtwork(feedback: feedback, size: size)

        physicsBody = BubblePhysicsBody.make(size: size)
        physicsBody?.categoryBitMask = PhysicsCategory.bubble
        physicsBody?.collisionBitMask = PhysicsCategory.bubble
            | PhysicsCategory.floor
            | PhysicsCategory.wall
        physicsBody?.contactTestBitMask = PhysicsCategory.bubble
        physicsBody?.restitution = 0.22
        physicsBody?.friction = 0.78
        physicsBody?.linearDamping = 0.68
        physicsBody?.angularDamping = 0.82
        physicsBody?.mass = 0.18
        physicsBody?.allowsRotation = false
    }

    required init?(coder aDecoder: NSCoder) {
        nil
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

    private func addBubbleArtwork(feedback: Feedback, size: CGSize) {
        let bubbleSprite = SKSpriteNode(texture: Self.sharedBubbleTexture)
        bubbleSprite.size = size
        bubbleSprite.color = UIColor(PocoTheme.bubble(feedback.bubbleColor))
        bubbleSprite.colorBlendFactor = 0.70
        bubbleSprite.zPosition = 0
        visualContainer.addChild(bubbleSprite)

        let isLarge = size.width >= 180
        let fontSize: CGFloat = isLarge ? 11.5 : 9.5
        let messageFont = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
        let lines = wrappedLines(
            feedback.message,
            font: messageFont,
            maximumWidth: size.width * 0.74
        )
        let lineHeight = fontSize + 2
        let firstLineY = lines.count == 1 ? 10 : 16
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
        let avatarRadius: CGFloat = isLarge ? 8.5 : 7
        let avatar = SKShapeNode(circleOfRadius: avatarRadius)
        avatar.fillColor = UIColor.black.withAlphaComponent(0.22)
        avatar.strokeColor = .clear
        avatar.position = CGPoint(x: leadingX + avatarRadius, y: authorY)
        avatar.zPosition = 2
        visualContainer.addChild(avatar)

        let initial = makeLabel(
            text: String(feedback.nickname.prefix(1)),
            font: .systemFont(ofSize: isLarge ? 7.5 : 6.5, weight: .bold),
            color: .white
        )
        initial.verticalAlignmentMode = .center
        initial.position = .zero
        avatar.addChild(initial)

        let nickname = makeLabel(
            text: feedback.nickname,
            font: .systemFont(ofSize: isLarge ? 9.5 : 8, weight: .medium),
            color: UIColor.secondaryLabel.withAlphaComponent(0.86)
        )
        nickname.horizontalAlignmentMode = .left
        nickname.position = CGPoint(x: leadingX + avatarRadius * 2 + 5, y: authorY)
        nickname.zPosition = 2
        visualContainer.addChild(nickname)
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

    private func wrappedLines(_ text: String, font: UIFont, maximumWidth: CGFloat) -> [String] {
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
        guard allLines.count > 2 else { return allLines }

        var secondLine = allLines[1]
        while !secondLine.isEmpty {
            let candidate = secondLine + "…"
            if (candidate as NSString).size(withAttributes: attributes).width <= maximumWidth {
                return [allLines[0], candidate]
            }
            secondLine.removeLast()
        }
        return [allLines[0], "…"]
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
    static let wallBottomStartY: CGFloat = 82
    static let dropRowSpacing: CGFloat = 50
    static let dropPreviewLimit = 2

    static func wallBubbleSize(for width: CGFloat) -> CGSize {
        CGSize(width: min(116, max(96, width * 0.29)), height: 60)
    }

    static func dropExistingBubbleSize(for width: CGFloat) -> CGSize {
        CGSize(width: min(112, max(96, (width - 20) / 3)), height: 58)
    }

    static func pendingBubbleSize(for width: CGFloat) -> CGSize {
        CGSize(width: min(184, width * 0.54), height: 88)
    }
}

struct BubbleFieldPlacement: Equatable {
    let feedbackID: UUID
    let position: CGPoint
    let rotation: CGFloat
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

        let bubbleSize = BubblePhysicsMetrics.wallBubbleSize(for: availableWidth)
        let halfWidth = bubbleSize.width * 0.48
        let minimumX = halfWidth + 4
        let maximumX = max(minimumX, availableWidth - halfWidth - 4)
        let horizontalClearance = bubbleSize.width * 0.88
        let verticalClearance = bubbleSize.height * 0.76
        var placements: [BubbleFieldPlacement] = []
        var currentTop = BubblePhysicsMetrics.wallBottomStartY

        for feedback in feedbacks.reversed() {
            let lowerBand = max(
                BubblePhysicsMetrics.wallBottomStartY,
                currentTop - verticalClearance * 0.78
            )
            var bestPosition = CGPoint(x: availableWidth / 2, y: currentTop)
            var bestScore = CGFloat.greatestFiniteMagnitude

            for attempt in 0..<9 {
                let x = minimumX
                    + stableUnit(feedback.id, salt: attempt) * (maximumX - minimumX)
                var y = lowerBand

                for existing in placements {
                    let deltaX = abs(x - existing.position.x)
                    guard deltaX < horizontalClearance else { continue }
                    let horizontalRatio = deltaX / horizontalClearance
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
                rotation: CGFloat((seed % 11) - 5) * .pi / 180
            )
            placements.append(placement)
            currentTop = max(currentTop, bestPosition.y)
        }

        return BubbleFieldLayout(
            placements: placements,
            contentHeight: currentTop + bubbleSize.height / 2 + 34
        )
    }
}

enum PhysicsCategory {
    static let bubble: UInt32 = 1 << 0
    static let floor: UInt32 = 1 << 1
    static let wall: UInt32 = 1 << 2
}

struct ConfigurationKey: Equatable {
    let ids: [UUID]
    let width: Int
    let height: Int
    var worldHeight = 0
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
    floor.physicsBody?.collisionBitMask = PhysicsCategory.bubble
    floor.physicsBody?.contactTestBitMask = PhysicsCategory.bubble
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
        wall.physicsBody?.collisionBitMask = PhysicsCategory.bubble
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
