import SpriteKit
import UIKit

@MainActor
private enum PuyoArtworkTexture {
    struct Artwork {
        let texture: SKTexture
        let aspectRatio: CGFloat
    }

    private static var cache: [String: Artwork] = [:]

    static func make(named assetName: String) -> Artwork? {
        if let cached = cache[assetName] {
            return cached
        }
        guard let image = UIImage(named: assetName) else { return nil }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        let artwork = Artwork(
            texture: texture,
            aspectRatio: max(0.72, min(1.65, image.size.width / max(image.size.height, 1)))
        )
        cache[assetName] = artwork
        return artwork
    }
}

@MainActor
final class PhysicsCompanionNode: SKNode {
    let feedbackID: UUID
    let avatar: BuiltInAvatar
    let visualSize: CGSize
    private(set) var isResolvingMerge = false

    private let visualContainer = SKNode()
    private var didGrantTapReward = false

    init(feedback: Feedback, height: CGFloat) {
        feedbackID = feedback.id
        avatar = PocoCompanion.avatar(for: feedback)

        let artwork = PuyoArtworkTexture.make(named: avatar.companionAssetName)
        let ratio = artwork?.aspectRatio ?? 1
        visualSize = CGSize(width: height * ratio, height: height)
        super.init()

        name = "poco-companion-\(feedback.id.uuidString)"
        addChild(visualContainer)

        if let artwork {
            let sprite = SKSpriteNode(texture: artwork.texture)
            sprite.name = "poco-companion"
            sprite.size = visualSize
            visualContainer.addChild(sprite)
        }

        // Keep the visible character friendly and readable while giving it a
        // smaller physical footprint. Nearby artwork can overlap slightly;
        // actual body contact still triggers the poyon response in the scene.
        physicsBody = SKPhysicsBody(circleOfRadius: height * 0.31)
        physicsBody?.categoryBitMask = PhysicsCategory.companion
        physicsBody?.collisionBitMask = PhysicsCategory.bubble
            | PhysicsCategory.companion
            | PhysicsCategory.floor
            | PhysicsCategory.wall
        physicsBody?.contactTestBitMask = PhysicsCategory.bubble
            | PhysicsCategory.companion
            | PhysicsCategory.floor
        physicsBody?.restitution = 0.10
        physicsBody?.friction = 0.72
        physicsBody?.linearDamping = 1.35
        physicsBody?.angularDamping = 1.0
        physicsBody?.mass = 0.045
        physicsBody?.allowsRotation = false
    }

    required init?(coder aDecoder: NSCoder) {
        nil
    }

    func playPoyon() {
        guard visualContainer.action(forKey: "poyon") == nil else { return }
        let action = SKAction.sequence([
            .group([
                .scaleX(to: 0.92, duration: 0.045),
                .scaleY(to: 0.84, duration: 0.045)
            ]),
            .group([
                .scaleX(to: 1.08, duration: 0.055),
                .scaleY(to: 1.13, duration: 0.055)
            ]),
            .scale(to: 1, duration: 0.05)
        ])
        action.timingMode = .easeInEaseOut
        visualContainer.run(action, withKey: "poyon")
    }

    func settleAfterContact() {
        guard let physicsBody else { return }
        physicsBody.velocity = CGVector(
            dx: physicsBody.velocity.dx * 0.08,
            dy: physicsBody.velocity.dy * 0.35
        )
        physicsBody.angularVelocity = 0
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

    func claimTapReward() -> Bool {
        guard !didGrantTapReward else { return false }
        didGrantTapReward = true
        return true
    }

    func beginMerge() -> Bool {
        guard !isResolvingMerge else { return false }
        isResolvingMerge = true
        physicsBody?.categoryBitMask = 0
        physicsBody?.collisionBitMask = 0
        physicsBody?.contactTestBitMask = 0
        return true
    }

    func playMergeAndRemove(reduceMotion: Bool, completion: @escaping () -> Void) {
        if reduceMotion {
            removeFromParent()
            completion()
            return
        }

        let action = SKAction.group([
            .scale(to: 0.05, duration: 0.18),
            .fadeOut(withDuration: 0.16)
        ])
        action.timingMode = .easeIn
        run(.sequence([action, .removeFromParent(), .run(completion)]))
    }
}

@MainActor
final class PhysicsRareCompanionNode: SKNode {
    let eventKey: String
    let kind: RareCompanionKind
    let visualSize: CGSize

    private let visualContainer = SKNode()
    private var didGrantTapReward = false

    init(kind: RareCompanionKind, eventKey: String, height: CGFloat = 96) {
        self.kind = kind
        self.eventKey = eventKey

        let artwork = PuyoArtworkTexture.make(named: kind.assetName)
        let ratio = artwork?.aspectRatio ?? 1
        visualSize = CGSize(width: height * ratio, height: height)
        super.init()

        name = "poco-rare-companion-\(eventKey)"
        addChild(visualContainer)

        if let artwork {
            let sprite = SKSpriteNode(texture: artwork.texture)
            sprite.name = "poco-rare-companion"
            sprite.size = visualSize
            visualContainer.addChild(sprite)
        }

        physicsBody = SKPhysicsBody(circleOfRadius: height * 0.29)
        physicsBody?.categoryBitMask = PhysicsCategory.companion
        physicsBody?.collisionBitMask = PhysicsCategory.bubble
            | PhysicsCategory.companion
            | PhysicsCategory.floor
            | PhysicsCategory.wall
        physicsBody?.contactTestBitMask = PhysicsCategory.bubble
            | PhysicsCategory.companion
            | PhysicsCategory.floor
        physicsBody?.restitution = 0.10
        physicsBody?.friction = 0.74
        physicsBody?.linearDamping = 1.35
        physicsBody?.angularDamping = 1.0
        physicsBody?.mass = 0.052
        physicsBody?.allowsRotation = false
    }

    required init?(coder aDecoder: NSCoder) {
        nil
    }

    func claimTapReward() -> Bool {
        guard !didGrantTapReward else { return false }
        didGrantTapReward = true
        return true
    }

    func playPoyon() {
        guard visualContainer.action(forKey: "poyon") == nil else { return }
        let action = SKAction.sequence([
            .group([
                .scaleX(to: 0.92, duration: 0.045),
                .scaleY(to: 0.84, duration: 0.045)
            ]),
            .group([
                .scaleX(to: 1.08, duration: 0.055),
                .scaleY(to: 1.13, duration: 0.055)
            ]),
            .scale(to: 1, duration: 0.05)
        ])
        action.timingMode = .easeInEaseOut
        visualContainer.run(action, withKey: "poyon")
    }

    func settleAfterContact() {
        guard let physicsBody else { return }
        physicsBody.velocity = CGVector(
            dx: physicsBody.velocity.dx * 0.08,
            dy: physicsBody.velocity.dy * 0.35
        )
        physicsBody.angularVelocity = 0
    }

    func playBirth(reduceMotion: Bool) {
        guard !reduceMotion else { return }
        visualContainer.alpha = 0
        visualContainer.setScale(0.08)
        visualContainer.run(
            .sequence([
                .group([
                    .fadeIn(withDuration: 0.12),
                    .scale(to: 1.22, duration: 0.20)
                ]),
                .scale(to: 0.92, duration: 0.08),
                .scale(to: 1, duration: 0.12)
            ]),
            withKey: "birth"
        )
        physicsBody?.applyImpulse(CGVector(dx: 0, dy: 0.22))
    }
}

enum CompanionPhysicsMetrics {
    static func height(for bubbleSize: CGSize) -> CGFloat {
        // The supplied artwork keeps transparent breathing room around Poco.
        // 1.9x canvas height renders the visible character at roughly 1.5x
        // the neighboring bubble while preserving the compact physics body.
        bubbleSize.height * 1.9
    }
}

nonisolated enum CompanionEvolution {
    static let birthProbability = 0.05

    static func mergeKey(_ first: UUID, _ second: UUID) -> String {
        let ids = [first.uuidString, second.uuidString].sorted()
        return "\(ids[0]):\(ids[1])"
    }

    static func shouldBirth(eventKey: String) -> Bool {
        pocoStableSeed(eventKey) % 100 < Int(birthProbability * 100)
    }
}
