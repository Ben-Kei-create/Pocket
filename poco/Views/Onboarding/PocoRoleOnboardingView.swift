import SwiftUI

struct PocoRoleOnboardingView: View {
    let guide: PocoOnboardingGuide
    let onComplete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pageIndex = 0

    private var pages: [PocoOnboardingPage] {
        switch guide {
        case .member:
            [
                PocoOnboardingPage(
                    character: .happy,
                    title: "ことばを届ける体験は、そのまま",
                    message: "作品を選んで感想を書き、フキダシを落とします。登録後は名前とアバターがプロフィールにつながります。",
                    footnote: "作品 → 感想を書く → フキダシを落とす"
                ),
                PocoOnboardingPage(
                    character: .letter,
                    title: "「作る」から作品の箱をつくれます",
                    message: "作品を登録すると、専用QRコードとリンクができます。無料ユーザーは3作品まで作成できます。",
                    footnote: "作る → 新しい作品 → QRを共有"
                ),
                PocoOnboardingPage(
                    character: .star,
                    title: "記録はマイページへ",
                    message: "送った感想、いいねしたフキダシ、届いた通知をまとめて確認できます。ログインボーナスは、その日最初の起動時に届きます。",
                    footnote: "分からなくなったら、設定からもう一度見られます"
                )
            ]
        case .pro:
            [
                PocoOnboardingPage(
                    character: .heart,
                    title: "反響を、もっと近くに",
                    message: "共感が集まったフキダシと、自分の作品・感想へ届いた反応を確認できます。",
                    footnote: "数字よりも、ことばが届いた実感を大切にします"
                ),
                PocoOnboardingPage(
                    character: .rare,
                    title: "キャラが合体するProの遊び",
                    message: "同じキャラが触れると合体します。95%で消滅し、5%でレアキャラが生まれます。",
                    footnote: "確率は課金やスターでは変化しません"
                ),
                PocoOnboardingPage(
                    character: .pro,
                    title: "広告なしで、作品づくりに集中",
                    message: "広告を表示せず、作品は30件まで。今後Pro機能が増えたときも、最初の一度だけ分かりやすく案内します。",
                    footnote: "この案内は設定からいつでも見直せます"
                )
            ]
        }
    }

    var body: some View {
        ZStack {
            PocoTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Text(guide == .pro ? "Poco Pro ガイド" : "Pocoユーザー ガイド")
                        .pocoFont(.headline, weight: .bold)
                    Spacer()
                    Button("スキップ", action: onComplete)
                        .pocoFont(.subheadline, weight: .medium)
                        .foregroundStyle(PocoTheme.secondaryText)
                        .frame(minHeight: 44)
                        .accessibilityHint("ガイドを閉じます")
                }
                .padding(.horizontal, PocoTheme.pagePadding)
                .padding(.top, 8)

                TabView(selection: $pageIndex) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        onboardingPage(page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                HStack(spacing: 8) {
                    ForEach(pages.indices, id: \.self) { index in
                        Capsule()
                            .fill(index == pageIndex ? PocoTheme.primary : PocoTheme.primary.opacity(0.18))
                            .frame(width: index == pageIndex ? 24 : 8, height: 8)
                    }
                }
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: pageIndex)
                .accessibilityHidden(true)
                .padding(.bottom, 20)

                Button {
                    if pageIndex == pages.count - 1 {
                        onComplete()
                    } else {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                            pageIndex += 1
                        }
                    }
                } label: {
                    Label(
                        pageIndex == pages.count - 1 ? "Pocoをはじめる" : "次へ",
                        systemImage: pageIndex == pages.count - 1 ? "checkmark" : "arrow.right"
                    )
                }
                .buttonStyle(PocoPrimaryButtonStyle())
                .padding(.horizontal, PocoTheme.pagePadding)
                .padding(.bottom, 18)
            }
        }
        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
        .accessibilityAddTraits(.isModal)
    }

    private func onboardingPage(_ page: PocoOnboardingPage) -> some View {
        VStack(spacing: 24) {
            Spacer(minLength: 12)

            PocoCharacterView(
                size: 176,
                expression: page.character,
                playsIdleAnimation: true,
                isInteractive: false
            )
                .shadow(color: PocoTheme.primary.opacity(0.1), radius: 22, y: 10)
                .accessibilityHidden(true)

            VStack(spacing: 12) {
                Text(page.title)
                    .pocoFont(.title2, weight: .bold)
                    .multilineTextAlignment(.center)

                Text(page.message)
                    .pocoFont(.body)
                    .foregroundStyle(PocoTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .frame(maxWidth: 340)

                Text(page.footnote)
                    .pocoFont(.caption, weight: .medium)
                    .foregroundStyle(PocoTheme.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(PocoTheme.primary.opacity(0.07), in: Capsule())
            }

            Spacer(minLength: 20)
        }
        .padding(.horizontal, PocoTheme.pagePadding)
        .accessibilityElement(children: .combine)
    }
}

private struct PocoOnboardingPage {
    let character: PocoCharacterExpression
    let title: String
    let message: String
    let footnote: String
}
