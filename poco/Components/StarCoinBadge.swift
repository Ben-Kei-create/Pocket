import SwiftUI

struct StarCoinBadge: View {
    let balance: Int

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "star.fill")
                .foregroundStyle(.yellow)
                .symbolRenderingMode(.hierarchical)
            Text(balance.formatted())
                .font(.subheadline.monospacedDigit().weight(.bold))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.thinMaterial, in: Capsule())
        .overlay {
            Capsule()
                .stroke(.yellow.opacity(0.28), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("スターコイン、\(balance)個")
    }
}
