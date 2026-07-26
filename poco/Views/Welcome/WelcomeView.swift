import SwiftUI

struct WelcomeView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 48)

            PocoLogoView()

            Text("あなたのことばが、\nクリエイターのチカラになる。")
                .font(.headline)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .lineSpacing(7)
                .foregroundStyle(.primary)
                .padding(.top, 26)

            Spacer(minLength: 28)

            WelcomeJarIllustration()
                .frame(height: 260)
                .accessibilityHidden(true)

            Spacer(minLength: 24)

            VStack(spacing: 12) {
                Button("はじめる", action: onContinue)
                    .buttonStyle(PocoPrimaryButtonStyle())
                    .accessibilityHint("ホーム画面を開きます")

                Button("ログイン", action: onContinue)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PocoTheme.primary)
                    .frame(minHeight: 44)
            }
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 24)
        .background(PocoTheme.background.ignoresSafeArea())
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
        .font(.system(size: 72, weight: .medium, design: .rounded))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Poco")
    }
}

private struct WelcomeJarIllustration: View {
    private let bubbles: [(CGFloat, CGFloat, CGFloat, BubbleColor)] = [
        (-52, 48, 72, .coral), (5, 54, 68, .yellow), (55, 50, 70, .blue),
        (-31, 3, 76, .mint), (27, 9, 74, .lavender), (0, -31, 64, .yellow)
    ]

    var body: some View {
        ZStack {
            Ellipse()
                .fill(.black.opacity(0.06))
                .frame(width: 230, height: 26)
                .offset(y: 112)
                .blur(radius: 4)

            GlassJarShape()
                .fill(.white.opacity(0.42))
                .overlay {
                    GlassJarShape()
                        .stroke(PocoTheme.glassStroke, lineWidth: 2)
                }
                .frame(width: 220, height: 205)
                .offset(y: 26)

            ForEach(Array(bubbles.enumerated()), id: \.offset) { index, bubble in
                BubbleCharacter(color: bubble.3, smiling: index.isMultiple(of: 2))
                    .frame(width: bubble.2, height: bubble.2 * 0.72)
                    .offset(x: bubble.0, y: bubble.1)
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
