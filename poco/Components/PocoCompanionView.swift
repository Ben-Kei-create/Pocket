import SwiftUI

nonisolated enum PocoCompanion {
    static let appearanceProbability = 0.15

    static func shouldAppear(for feedback: Feedback) -> Bool {
        let seed = feedback.id.uuidString.unicodeScalars.reduce(0) { partial, scalar in
            (partial &* 31 &+ Int(scalar.value)) & 0x7fff_ffff
        }
        return seed % 100 < Int(appearanceProbability * 100)
    }

    static func assetName(for feedback: Feedback) -> String {
        avatar(for: feedback).companionAssetName
    }

    static func avatar(for feedback: Feedback) -> BuiltInAvatar {
        guard let avatarName = feedback.senderAvatarName,
              let avatar = BuiltInAvatar(rawValue: avatarName) else {
            return .cat
        }
        return avatar
    }
}

struct PocoCompanionView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let feedback: Feedback
    var size: CGFloat = 54

    @State private var scaleX: CGFloat = 1
    @State private var scaleY: CGFloat = 1

    var body: some View {
        Button {
            playPoyon()
        } label: {
            Image(PocoCompanion.assetName(for: feedback))
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .contentShape(Circle())
                .scaleEffect(x: scaleX, y: scaleY)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("フキダシのキャラクター")
        .accessibilityHint("タップすると、ぷよっと動きます")
    }

    private func playPoyon() {
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 0.08)) {
            scaleX = 1.16
            scaleY = 0.82
        }
        Task {
            try? await Task.sleep(for: .milliseconds(85))
            withAnimation(.spring(response: 0.3, dampingFraction: 0.48)) {
                scaleX = 1
                scaleY = 1
            }
        }
    }
}
