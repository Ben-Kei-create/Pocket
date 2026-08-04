import SwiftUI

struct StarCoinBadge: View {
    let balance: Int

    var body: some View {
        HStack(spacing: 5) {
            Image(PocoArtwork.starCoin)
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
                .accessibilityHidden(true)
            Text(balance.formatted())
                .pocoFont(.subheadline, weight: .bold).monospacedDigit()
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
