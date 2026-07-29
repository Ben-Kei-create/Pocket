import SwiftUI

struct ProjectLimitReachedView: View {
    @Environment(PocoStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var showsMembership = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: store.role == .pro ? "shippingbox.fill" : "sparkles")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(PocoTheme.primary)
                    .frame(width: 88, height: 88)
                    .background(PocoTheme.bubble(.yellow).opacity(0.8), in: Circle())
                    .accessibilityHidden(true)

                VStack(spacing: 8) {
                    Text(title)
                        .pocoFont(.title2, weight: .bold)
                    Text(message)
                        .pocoFont(.subheadline)
                        .foregroundStyle(PocoTheme.secondaryText)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 9) {
                    HStack {
                        Text("現在の作品")
                        Spacer()
                        Text(
                            "\(store.currentUserProjects.count) / "
                                + "\(store.capabilities.maximumProjectCount)"
                        )
                        .pocoFont(.headline).monospacedDigit()
                    }
                    ProgressView(
                        value: Double(store.currentUserProjects.count),
                        total: Double(max(1, store.capabilities.maximumProjectCount))
                    )
                    .tint(PocoTheme.primary)
                }
                .padding(17)
                .pocoCard()
                .accessibilityElement(children: .combine)

                if store.role == .user {
                    VStack(spacing: 12) {
                        Button {
                            showsMembership = true
                        } label: {
                            Label("Poco Proで30作品まで増やす", systemImage: "heart.fill")
                        }
                        .buttonStyle(PocoPrimaryButtonStyle())

                        Text("Poco Proでは、作品の記録・限定背景・広告なしも利用できます。")
                            .pocoFont(.caption)
                            .foregroundStyle(PocoTheme.tertiaryText)
                            .multilineTextAlignment(.center)
                    }
                }

                Button("作品一覧に戻る", action: dismiss.callAsFunction)
                    .pocoFont(.subheadline, weight: .medium)
                    .foregroundStyle(PocoTheme.primary)

                Spacer()
            }
            .padding(PocoTheme.pagePadding)
            .background(PocoTheme.groupedBackground)
            .navigationTitle("作品数の上限")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる", action: dismiss.callAsFunction)
                }
            }
            .sheet(isPresented: $showsMembership) {
                PocoMembershipView()
            }
        }
    }

    private var title: String {
        store.role == .pro ? "30作品まで登録済みです" : "無料プランの3作品まで登録済みです"
    }

    private var message: String {
        if store.role == .pro {
            return "新しい作品を追加する前に、現在の作品を確認してください。"
        }
        return "今の作品はそのままに、Poco Proへ進むと最大30作品まで登録できます。"
    }
}
