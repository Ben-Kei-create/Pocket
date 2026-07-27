import SwiftUI

struct RegistrationGateView: View {
    @Environment(PocoStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var avatarName: String?
    @State private var avatarImageData: Data?
    var onRegistered: (() -> Void)?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    VStack(spacing: 9) {
                        Text("作品を作るには登録が必要です")
                            .font(.title2.bold())
                        Text("登録すると、作品ページ・QRコード・届いた感想を管理できます。感想を送るだけなら登録は必要ありません。")
                            .font(.subheadline)
                            .foregroundStyle(PocoTheme.secondaryText)
                            .multilineTextAlignment(.center)
                    }

                    ProfileAvatarPicker(
                        avatarName: $avatarName,
                        avatarImageData: $avatarImageData
                    )

                    VStack(spacing: 12) {
                        benefit("作品ページを作成", symbol: "plus.square")
                        benefit("QRコードとリンクを共有", symbol: "qrcode")
                        benefit("届いたことばを管理", symbol: "bubble.left.and.bubble.right")
                    }

                    registrationControl

                    Text("閲覧・感想投稿・いいねはゲストのまま利用できます。")
                        .font(.caption)
                        .foregroundStyle(PocoTheme.tertiaryText)
                }
                .padding(PocoTheme.pagePadding)
            }
            .background(PocoTheme.background)
            .navigationTitle("ユーザー登録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる", action: dismiss.callAsFunction)
                }
            }
            .onChange(of: store.authenticationState) { _, state in
                if state == .authenticated {
                    onRegistered?()
                    dismiss()
                }
            }
        }
    }

    @ViewBuilder
    private var registrationControl: some View {
        if store.backendMode == .mock {
            Button {
                store.registerPreviewAccount(
                    avatarName: avatarName,
                    avatarImageData: avatarImageData
                )
                onRegistered?()
                dismiss()
            } label: {
                Label("デモでユーザー登録する", systemImage: "person.badge.plus")
            }
            .buttonStyle(PocoPrimaryButtonStyle())
        } else {
            AppleRegistrationButton(
                avatarName: avatarName,
                avatarImageData: avatarImageData
            )

            if store.authenticationState == .authenticating {
                ProgressView("登録しています…")
                    .font(.caption)
            }

            if case .error(let message) = store.authenticationState {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func benefit(_ text: String, symbol: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(PocoTheme.primary)
                .frame(width: 26)
            Text(text)
                .font(.subheadline.weight(.medium))
            Spacer()
            Image(systemName: "checkmark")
                .foregroundStyle(PocoTheme.secondaryText)
        }
        .padding(15)
        .pocoCard(cornerRadius: PocoTheme.cornerSmall)
    }
}
