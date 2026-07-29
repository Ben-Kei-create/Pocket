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
    private let bubbles: [(CGFloat, CGFloat, CGFloat, Double, BubbleColor)] = [
        (-94, 64, 68, -5, .coral), (-30, 72, 72, 3, .yellow), (43, 69, 70, -2, .blue),
        (98, 53, 62, 5, .pink), (-72, 9, 74, 2, .mint), (2, 14, 76, -3, .lavender),
        (76, -1, 70, 4, .yellow), (-38, -45, 70, -2, .blue), (38, -50, 74, 3, .coral)
    ]

    var body: some View {
        ZStack {
            ForEach(Array(bubbles.enumerated()), id: \.offset) { index, bubble in
                BubbleCharacter(color: bubble.4, smiling: index.isMultiple(of: 2))
                    .frame(width: bubble.2, height: bubble.2 * 0.72)
                    .rotationEffect(.degrees(bubble.3))
                    .offset(x: bubble.0, y: bubble.1)
                    .shadow(color: .black.opacity(0.055), radius: 5, y: 4)
            }
        }
    }
}

private struct BubbleCharacter: View {
    let color: BubbleColor
    let smiling: Bool

    var body: some View {
        ZStack {
            Ellipse()
                .fill(PocoTheme.bubble(color))
            HStack(spacing: 10) {
                Circle().fill(.black.opacity(0.33)).frame(width: 3.5, height: 3.5)
                Circle().fill(.black.opacity(0.33)).frame(width: 3.5, height: 3.5)
            }
            Path { path in
                if smiling {
                    path.move(to: CGPoint(x: 27, y: 31))
                    path.addQuadCurve(
                        to: CGPoint(x: 37, y: 31),
                        control: CGPoint(x: 32, y: 37)
                    )
                }
            }
            .stroke(.black.opacity(0.28), lineWidth: 1.2)
        }
    }
}
