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

}

struct RegistrationGateView: View {
    @Environment(PocoStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var nickname = ""
    @State private var avatarName: String? = BuiltInAvatar.cat.rawValue
    @State private var avatarImageData: Data?
    var context: RegistrationGateContext = .createProject
    var onRegistered: (() -> Void)?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    Text(context.title)
                        .pocoFont(.title2, weight: .bold)
                        .multilineTextAlignment(.center)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("ニックネーム")
                            .pocoFont(.subheadline, weight: .medium)
                        TextField("Pocoで使う名前", text: $nickname)
                            .textContentType(.nickname)
                            .textInputAutocapitalization(.never)
                            .padding(14)
                            .background(PocoTheme.cardBackground)
                            .clipShape(
                                RoundedRectangle(
                                    cornerRadius: PocoTheme.cornerSmall,
                                    style: .continuous
                                )
                            )
                            .onChange(of: nickname) { _, value in
                                if value.count > 80 {
                                    nickname = String(value.prefix(80))
                                }
                            }
                        HStack {
                            Text("フキダシとプロフィールに表示されます")
                            Spacer()
                            Text("\(nickname.count)/80")
                        }
                        .pocoFont(.caption)
                        .foregroundStyle(PocoTheme.tertiaryText)
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
                    displayName: normalizedNickname,
                    avatarName: avatarName,
                    avatarImageData: avatarImageData
                )
                onRegistered?()
                dismiss()
            } label: {
                Label("デモでユーザー登録する", systemImage: "person.badge.plus")
            }
            .buttonStyle(PocoPrimaryButtonStyle())
            .disabled(normalizedNickname.isEmpty)
        } else {
            AppleRegistrationButton(
                displayName: normalizedNickname,
                avatarName: avatarName,
                avatarImageData: avatarImageData
            )

            if store.authenticationState == .authenticating {
                ProgressView("登録しています…")
                    .pocoFont(.caption)
            }

            if case .error(let message) = store.authenticationState {
                Text(message)
                    .pocoFont(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var normalizedNickname: String {
        nickname.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func benefit(_ text: String, symbol: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(PocoTheme.primary)
                .frame(width: 26)
            Text(text)
                .pocoFont(.subheadline, weight: .medium)
            Spacer()
            Image(systemName: "checkmark")
                .foregroundStyle(PocoTheme.secondaryText)
        }
        .padding(15)
        .pocoCard(cornerRadius: PocoTheme.cornerSmall)
    }
}
