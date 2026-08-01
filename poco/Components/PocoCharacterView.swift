import SwiftUI

nonisolated enum PocoCharacterExpression: String, CaseIterable, Sendable {
    case calm = "PocoCharacterDefault"
    case happy = "PocoCharacterHappy"
    case heart = "PocoCharacterHeart"
    case question = "PocoCharacterQuestion"
    case letter = "PocoCharacterLetter"
    case worried = "PocoCharacterSorry"
    case pro = "PocoCharacterPro"
    case rare = "PocoCharacterRare"
    case star = "PocoCharacterStar"
    case sleep = "PocoCharacterSleep"

    var accessibilityLabel: String {
        switch self {
        case .calm: "Poco"
        case .happy: "喜んでいるPoco"
        case .heart: "ハートを抱えるPoco"
        case .question: "質問するPoco"
        case .letter: "手紙を届けるPoco"
        case .worried: "困っているPoco"
        case .pro: "Poco Pro"
        case .rare: "レアPoco"
        case .star: "スターを抱えるPoco"
        case .sleep: "眠っているPoco"
        }
    }
}

nonisolated enum PocoArtwork {
    static let starCoin = "PocoStarCoin"
    static let creatorHeart = "PocoCreatorHeart"
    static let creatorHeartReceived = "PocoCreatorHeartReceived"
}

struct PocoCharacterView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var size: CGFloat
    var expression: PocoCharacterExpression = .calm
    var playsIdleAnimation = false
    var isInteractive = true

    @State private var scaleX: CGFloat = 1
    @State private var scaleY: CGFloat = 1
    @State private var verticalOffset: CGFloat = 0

    var body: some View {
        Image(expression.rawValue)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .scaleEffect(x: scaleX, y: scaleY, anchor: .bottom)
            .offset(y: verticalOffset)
            .contentShape(Circle())
            .onTapGesture {
                guard isInteractive else { return }
                playPoyon()
            }
            .task(id: playsIdleAnimation && !reduceMotion) {
                guard playsIdleAnimation, !reduceMotion else {
                    verticalOffset = 0
                    return
                }
                while !Task.isCancelled {
                    withAnimation(.easeInOut(duration: 1.25)) {
                        verticalOffset = -5
                    }
                    try? await Task.sleep(for: .milliseconds(1_250))
                    withAnimation(.easeInOut(duration: 1.25)) {
                        verticalOffset = 0
                    }
                    try? await Task.sleep(for: .milliseconds(1_250))
                }
            }
            .accessibilityLabel(expression.accessibilityLabel)
            .accessibilityHint(isInteractive ? "タップすると、ぷよっと動きます" : "")
    }

    private func playPoyon() {
        guard !reduceMotion else { return }
        withAnimation(.easeIn(duration: 0.06)) {
            scaleX = 1.12
            scaleY = 0.82
            verticalOffset = 3
        }
        Task {
            try? await Task.sleep(for: .milliseconds(65))
            withAnimation(.spring(response: 0.28, dampingFraction: 0.48)) {
                scaleX = 1
                scaleY = 1
                verticalOffset = 0
            }
        }
    }
}
