import SwiftUI

nonisolated enum PocoCompanion {
    static func assetName(for feedback: Feedback) -> String {
        if let avatarName = feedback.senderAvatarName,
           let avatar = BuiltInAvatar(rawValue: avatarName) {
            return avatar.companionAssetName
        }

        let avatars = BuiltInAvatar.allCases
        let seed = feedback.id.uuidString.unicodeScalars.reduce(0) { partial, scalar in
            (partial &* 31 &+ Int(scalar.value)) & 0x7fff_ffff
        }
        return avatars[seed % avatars.count].companionAssetName
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
