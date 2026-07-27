import SpriteKit
import UIKit

@MainActor
final class PhysicsCompanionNode: SKNode {
    let feedbackID: UUID
    let visualSize: CGSize

    private let visualContainer = SKNode()

    init(feedback: Feedback, height: CGFloat) {
        feedbackID = feedback.id

        let assetName = PocoCompanion.assetName(for: feedback)
        let image = UIImage(named: assetName)
        let ratio = image.map {
            max(0.72, min(1.55, $0.size.width / max($0.size.height, 1)))
        } ?? 1
        visualSize = CGSize(width: height * ratio, height: height)
        super.init()

        name = "poco-companion-\(feedback.id.uuidString)"
        addChild(visualContainer)

        if let image {
            let sprite = SKSpriteNode(texture: SKTexture(image: image))
            sprite.name = "poco-companion"
            sprite.size = visualSize
            visualContainer.addChild(sprite)
        }

        physicsBody = SKPhysicsBody(circleOfRadius: height * 0.40)
        physicsBody?.categoryBitMask = PhysicsCategory.companion
        physicsBody?.collisionBitMask = PhysicsCategory.bubble
            | PhysicsCategory.companion
            | PhysicsCategory.floor
            | PhysicsCategory.wall
        physicsBody?.contactTestBitMask = PhysicsCategory.bubble
            | PhysicsCategory.companion
            | PhysicsCategory.floor
        physicsBody?.restitution = 0.48
        physicsBody?.friction = 0.56
        physicsBody?.linearDamping = 0.52
        physicsBody?.angularDamping = 0.86
        physicsBody?.mass = 0.075
        physicsBody?.allowsRotation = false
    }

    required init?(coder aDecoder: NSCoder) {
        nil
    }

    func playPoyon() {
        guard visualContainer.action(forKey: "poyon") == nil else { return }
        let action = SKAction.sequence([
            .group([
                .scaleX(to: 1.18, duration: 0.07),
                .scaleY(to: 0.80, duration: 0.07)
            ]),
            .group([
                .scaleX(to: 0.91, duration: 0.08),
                .scaleY(to: 1.15, duration: 0.08)
            ]),
            .scale(to: 1, duration: 0.12)
        ])
        action.timingMode = .easeInEaseOut
        visualContainer.run(action, withKey: "poyon")
    }

    func playSpawn(reduceMotion: Bool, horizontalDirection: CGFloat) {
        guard !reduceMotion else { return }

        visualContainer.alpha = 0
        visualContainer.setScale(0.18)
        let appear = SKAction.group([
            .fadeIn(withDuration: 0.10),
            .scale(to: 1.14, duration: 0.15)
        ])
        appear.timingMode = .easeOut
        visualContainer.run(
            .sequence([appear, .scale(to: 1, duration: 0.11)]),
            withKey: "spawn"
        )
        physicsBody?.applyImpulse(
            CGVector(dx: horizontalDirection * 0.085, dy: 0.18)
        )
    }
}

enum CompanionPhysicsMetrics {
    static func height(for bubbleSize: CGSize) -> CGFloat {
        min(38, max(27, bubbleSize.height * 0.48))
    }
}
