import Foundation

enum BubbleArtworkStyle: String, Sendable {
    case standardCapsule
    case classicSpeech

    static let active: Self = .standardCapsule

    var textureAssetName: String {
        switch self {
        case .standardCapsule:
            "BubbleCapsuleTexture"
        case .classicSpeech:
            "BubbleTexture"
        }
    }
}
