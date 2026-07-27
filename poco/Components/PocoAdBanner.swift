import SwiftUI

struct PocoAdBanner: View {
    let onRemoveAds: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(PocoTheme.bubble(.yellow).opacity(0.65))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: "sparkles")
                        .foregroundStyle(PocoTheme.primary)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text("スポンサー広告")
                    .font(.caption2)
                    .foregroundStyle(PocoTheme.secondaryText)
                Text("ここに広告が表示されます")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
            }

            Spacer(minLength: 8)

            Button("広告を消す", action: onRemoveAds)
                .font(.caption.weight(.semibold))
                .foregroundStyle(PocoTheme.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Divider()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("スポンサー広告。Pocoメンバーになると広告を非表示にできます")
    }
}
