import SwiftUI

struct ProjectPublishingGuidelinesView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Pocoは、自分の作品に感想を受け取ることを基本にしています。ファンが非公式の感想箱を作ることもできますが、公式ページと誤解されない表示になります。")
                        .pocoFont(.body)
                        .lineSpacing(5)

                    guideline(
                        symbol: "person.crop.circle.badge.checkmark",
                        title: "正しい立場を選ぶ",
                        detail: "制作者本人、許可を得ている、ファンの感想箱から、実際の関係に合うものを選びます。"
                    )
                    guideline(
                        symbol: "person.crop.circle.badge.xmark",
                        title: "なりすましをしない",
                        detail: "作者や権利者を名乗ったり、公式ページであるかのような説明をしたりしません。"
                    )
                    guideline(
                        symbol: "photo.badge.checkmark",
                        title: "画像と文章の権利を守る",
                        detail: "自分が権利を持つ素材、または掲載の許可を得た素材だけを使います。許可がない表紙・ロゴ・画像は登録しません。"
                    )
                    guideline(
                        symbol: "heart.circle",
                        title: "ファンの感想箱は非公式",
                        detail: "作品を応援する目的で作り、作者本人の公式ページとは表示しません。権利者から要請があった場合は非公開・削除の対象になります。"
                    )
                }
                .padding(PocoTheme.pagePadding)
            }
            .background(PocoTheme.background)
            .navigationTitle("作品登録のルール")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる", action: dismiss.callAsFunction)
                }
            }
        }
    }

    private func guideline(symbol: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .pocoFont(.title3)
                .foregroundStyle(PocoTheme.primary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .pocoFont(.headline, weight: .medium)
                Text(detail)
                    .pocoFont(.subheadline)
                    .foregroundStyle(PocoTheme.secondaryText)
                    .lineSpacing(4)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
