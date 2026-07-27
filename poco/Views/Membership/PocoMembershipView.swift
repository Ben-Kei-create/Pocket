import SwiftUI

struct PocoMembershipView: View {
    @Environment(PocoStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    memberMark

                    VStack(spacing: 8) {
                        Text("Pocoメンバー")
                            .font(.largeTitle.bold())
                        Text("届いたことばの反響を、もっと近くに。")
                            .font(.subheadline)
                            .foregroundStyle(PocoTheme.secondaryText)
                    }
                    .multilineTextAlignment(.center)

                    VStack(spacing: 12) {
                        benefit("人気のフキダシがわかる", symbol: "chart.line.uptrend.xyaxis")
                        benefit("自分の作品が受け取ったいいねを確認", symbol: "heart.text.square")
                        benefit("自分の感想についたいいねを確認", symbol: "bubble.left.and.text.bubble.right")
                        benefit("広告なしで楽しめる", symbol: "rectangle.badge.xmark")
                    }

                    VStack(spacing: 5) {
                        Text("月額300円（予定）")
                            .font(.title3.bold())
                        Text("いつでも解約できます")
                            .font(.caption)
                            .foregroundStyle(PocoTheme.secondaryText)
                    }

                    if store.backendMode == .mock {
                        Button {
                            store.activatePreviewMembership()
                            dismiss()
                        } label: {
                            Label("デモでメンバー機能を見る", systemImage: "sparkles")
                        }
                        .buttonStyle(PocoPrimaryButtonStyle())
                    } else {
                        Button("App Store課金は準備中") {}
                            .buttonStyle(PocoPrimaryButtonStyle())
                            .disabled(true)
                    }

                    Text("本番ではStoreKitの購入確認後に会員機能が有効になります。")
                        .font(.caption)
                        .foregroundStyle(PocoTheme.tertiaryText)
                        .multilineTextAlignment(.center)
                }
                .padding(PocoTheme.pagePadding)
            }
            .background(PocoTheme.background)
            .navigationTitle("メンバーシップ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる", action: dismiss.callAsFunction)
                }
            }
        }
    }

    private var memberMark: some View {
        Circle()
            .fill(PocoTheme.bubble(.pink))
            .frame(width: 92, height: 92)
            .overlay {
                Image(systemName: "heart.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .shadow(color: PocoTheme.primary.opacity(0.16), radius: 20, y: 8)
            .accessibilityHidden(true)
    }

    private func benefit(_ title: String, symbol: String) -> some View {
        HStack(spacing: 13) {
            Image(systemName: symbol)
                .frame(width: 28)
                .foregroundStyle(PocoTheme.primary)
            Text(title)
                .font(.subheadline.weight(.medium))
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(PocoTheme.bubble(.mint))
        }
        .padding(15)
        .pocoCard(cornerRadius: PocoTheme.cornerSmall)
    }
}
