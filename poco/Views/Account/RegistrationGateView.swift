import SwiftUI

enum RegistrationGateContext {
    case createProject
    case account
    case afterFeedback

    var title: String {
        switch self {
        case .createProject:
            "作品を作るには登録が必要です"
        case .account:
            "Pocoユーザーに登録"
        case .afterFeedback:
            "ことばを届けたあとに"
        }
    }

    var message: String {
        switch self {
        case .createProject:
            "登録すると、作品ページ・QRコード・届いた感想を管理できます。感想を送るだけなら登録は必要ありません。"
        case .account:
            "登録すると、プロフィールと検索できる@IDを持ち、作品の感想箱を作れます。"
        case .afterFeedback:
            "無料登録すると、次から名前とアバター付きで感想を送り、自分の作品の感想箱も作れます。"
        }
    }
}

struct RegistrationGateView: View {
    @Environment(PocoStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var avatarName: String?
    @State private var avatarImageData: Data?
    var context: RegistrationGateContext = .createProject
    var onRegistered: (() -> Void)?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    VStack(spacing: 9) {
                        Text(context.title)
                            .font(.title2.bold())
                        Text(context.message)
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
                        benefit("検索できる@IDを取得", symbol: "at")
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
