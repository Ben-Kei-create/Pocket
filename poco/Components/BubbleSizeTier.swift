import Foundation

enum BubbleSizeTier: Sendable {
    case small
    case medium
    case large

    init(message: String) {
        let characterCount = message.filter { !$0.isWhitespace }.count
        switch characterCount {
        case ...16:
            self = .small
        case ...34:
            self = .medium
        default:
            self = .large
        }
    }
}
