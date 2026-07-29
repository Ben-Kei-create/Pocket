import AuthenticationServices
import SwiftUI

struct AppleRegistrationButton: View {
    let displayName: String
    let avatarName: String?
    let avatarImageData: Data?

    @Environment(PocoStore.self) private var store
    @State private var rawNonce: String?

    var body: some View {
        SignInWithAppleButton(.signUp) { request in
            let nonce = AppleSignInNonce.make()
            rawNonce = nonce
            request.requestedScopes = [.fullName, .email]
            request.nonce = AppleSignInNonce.hash(nonce)
        } onCompletion: { result in
            handle(result)
        }
        .signInWithAppleButtonStyle(.black)
        .frame(height: 52)
        .clipShape(RoundedRectangle(cornerRadius: PocoTheme.cornerSmall, style: .continuous))
        .disabled(
            store.authenticationState == .authenticating
                || displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        )
        .accessibilityLabel("Appleでユーザー登録")
    }

    private func handle(_ result: Result<ASAuthorization, any Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let identityToken = String(data: tokenData, encoding: .utf8),
                  let rawNonce else {
                store.reportAppleSignInFailure("Appleの認証情報を取得できませんでした。")
                return
            }

            let appleFullName = credential.fullName.flatMap {
                PersonNameComponentsFormatter.localizedString(from: $0, style: .default)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            Task {
                await store.signInWithApple(
                    identityToken: identityToken,
                    rawNonce: rawNonce,
                    displayName: displayName,
                    appleFullName: appleFullName?.isEmpty == false ? appleFullName : nil,
                    email: credential.email,
                    avatarName: avatarName,
                    avatarImageData: avatarImageData
                )
            }
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code != .canceled {
                store.reportAppleSignInFailure("Appleでの登録を完了できませんでした。")
            }
        }
    }
}
