import SwiftUI

struct WelcomeView: View {
    let onContinue: () -> Void
    let onOpenProjectURL: (URL) -> Void
    @State private var showsScanner = false
    @State private var showsRegistration = false

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 32)

                    PocoLogoView()

                    Text("あなたのことばが、\nクリエイターのチカラになる。")
                        .pocoFont(.headline, weight: .medium)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.center)
                        .lineSpacing(7)
                        .foregroundStyle(.primary)
                        .padding(.top, 20)

                    Spacer(minLength: 16)

                    WelcomeBubbleFieldIllustration()
                        .frame(height: 220)
                        .accessibilityHidden(true)

                    Spacer(minLength: 18)

                    VStack(spacing: 12) {
                        Button {
                            showsScanner = true
                        } label: {
                            Label("QRコードで感想を送る", systemImage: "qrcode.viewfinder")
                        }
                        .buttonStyle(PocoPrimaryButtonStyle())
                        .accessibilityHint("登録せずに作品のQRコードを読み取れます")

                        Button {
                            onContinue()
                        } label: {
                            Label("作品を検索する", systemImage: "magnifyingglass")
                        }
                        .buttonStyle(PocoSecondaryButtonStyle())
                        .accessibilityHint("作品名やクリエイターIDから探します")

                        Button("無料登録・ログイン") {
                            showsRegistration = true
                        }
                        .pocoFont(.subheadline, weight: .medium)
                        .foregroundStyle(PocoTheme.primary)
                        .frame(minHeight: 44)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 24)
                .frame(minHeight: geometry.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(PocoTheme.background.ignoresSafeArea())
        .sheet(isPresented: $showsScanner) {
            QRCodeScannerSheet(onScan: onOpenProjectURL)
        }
        .sheet(isPresented: $showsRegistration) {
            RegistrationGateView(context: .account, onRegistered: onContinue)
        }
    }
}

private struct PocoLogoView: View {
    private let letters: [(String, Color)] = [
        ("P", PocoTheme.primary),
        ("o", PocoTheme.bubble(.mint)),
        ("c", Color(red: 1.0, green: 0.70, blue: 0.05)),
        ("o", PocoTheme.bubble(.lavender))
    ]

    var body: some View {
        HStack(spacing: -3) {
            ForEach(Array(letters.enumerated()), id: \.offset) { _, item in
                Text(item.0)
                    .foregroundStyle(item.1)
            }
        }
        .pocoFixedFont(size: 72, weight: .medium)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Poco")
    }
}

private struct WelcomeBubbleFieldIllustration: View {
    var body: some View {
        ZStack {
            Image(systemName: "bubble.left.fill")
                .font(.system(size: 34))
                .foregroundStyle(PocoTheme.bubble(.lavender).opacity(0.62))
                .offset(x: -92, y: -54)

            Image(systemName: "bubble.right.fill")
                .font(.system(size: 28))
                .foregroundStyle(PocoTheme.bubble(.blue).opacity(0.66))
                .offset(x: 96, y: -22)

            PocoCharacterView(
                size: 184,
                expression: .happy,
                playsIdleAnimation: true
            )
                .shadow(color: PocoTheme.primary.opacity(0.13), radius: 12, y: 8)
        }
        .accessibilityElement(children: .contain)
    }
}
