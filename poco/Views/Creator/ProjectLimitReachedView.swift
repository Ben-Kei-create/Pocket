import SwiftUI

struct ProjectLimitReachedView: View {
    @Environment(PocoStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var showsMembership = false
    @State private var showsRedemptionConfirmation = false
    @State private var isRedeeming = false
    @State private var redemptionMessage: String?
    @State private var redemptionError: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                limitArtwork

                Text(title)
                    .pocoFont(.title2, weight: .bold)
                    .multilineTextAlignment(.center)

                VStack(spacing: 9) {
                    HStack {
                        Text("現在の作品")
                        Spacer()
                        Text(
                            "\(store.currentUserProjects.count) / "
                                + "\(store.maximumProjectCount)"
                        )
                        .pocoFont(.headline).monospacedDigit()
                    }
                    ProgressView(
                        value: Double(store.currentUserProjects.count),
                        total: Double(max(1, store.maximumProjectCount))
                    )
                    .tint(PocoTheme.primary)
                }
                .padding(17)
                .pocoCard()
                .accessibilityElement(children: .combine)

                if store.role == .user {
                    VStack(spacing: 12) {
                        if let nextSlot = store.projectSlotStatus.nextSlotNumber,
                           let nextCost = store.projectSlotStatus.nextSlotCost {
                            projectSlotRedemptionCard(nextSlot: nextSlot, cost: nextCost)
                        } else {
                            Label("無料枠は最大5作品まで解放済みです", systemImage: "checkmark.seal.fill")
                                .pocoFont(.subheadline, weight: .medium)
                                .foregroundStyle(PocoTheme.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .pocoCard()
                        }

                        Button {
                            showsMembership = true
                        } label: {
                            Label("Poco Proで30作品まで増やす", systemImage: "heart.fill")
                        }
                        .buttonStyle(PocoPrimaryButtonStyle())

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
            .confirmationDialog(
                "作品枠を解放しますか？",
                isPresented: $showsRedemptionConfirmation,
                titleVisibility: .visible
            ) {
                if let nextSlot = store.projectSlotStatus.nextSlotNumber,
                   let cost = store.projectSlotStatus.nextSlotCost {
                    Button("\(cost)⭐︎で\(nextSlot)作品目を解放") {
                        redeemProjectSlot(targetSlot: nextSlot)
                    }
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("解放した無料枠はPoco Proを解約した後も残ります。取り消しはできません。")
            }
            .alert(
                "作品枠を解放できませんでした",
                isPresented: Binding(
                    get: { redemptionError != nil },
                    set: { if !$0 { redemptionError = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(redemptionError ?? "")
            }
            .task {
                await store.loadProjectSlotStatus(reportsErrors: false)
            }
        }
    }

    private var title: String {
        if store.role == .pro { return "30作品まで登録済みです" }
        if store.currentUserProjects.count < store.maximumProjectCount {
            return "新しい作品を作れます"
        }
        return "無料プランの\(store.maximumProjectCount)作品まで登録済みです"
    }

    @ViewBuilder
    private var limitArtwork: some View {
        if store.role == .user {
            Image(PocoArtwork.starCoinBundle)
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .accessibilityHidden(true)
        } else {
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(PocoTheme.primary)
                .frame(width: 88, height: 88)
                .background(PocoTheme.bubble(.yellow).opacity(0.8), in: Circle())
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private func projectSlotRedemptionCard(nextSlot: Int, cost: Int) -> some View {
        let missingStars = max(0, cost - store.starCoinBalance)
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("無料の作品枠を増やす")
                        .pocoFont(.headline, weight: .medium)
                }
                Spacer()
                StarCoinBadge(balance: store.starCoinBalance)
            }

            Button {
                showsRedemptionConfirmation = true
            } label: {
                if isRedeeming {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                } else {
                    Label("\(cost)⭐︎で\(nextSlot)作品目を解放", systemImage: "lock.open.fill")
                }
            }
            .buttonStyle(PocoPrimaryButtonStyle())
            .disabled(isRedeeming || missingStars > 0)
            .opacity(missingStars > 0 ? 0.48 : 1)

            if let redemptionMessage {
                Text(redemptionMessage)
                    .pocoFont(.caption, weight: .medium)
                    .foregroundStyle(PocoTheme.primary)
            } else if missingStars > 0 {
                Text("あと\(missingStars)⭐︎で解放できます。")
                    .pocoFont(.caption)
                    .foregroundStyle(PocoTheme.secondaryText)
            }
        }
        .padding(17)
        .pocoCard()
        .accessibilityElement(children: .contain)
    }

    private func redeemProjectSlot(targetSlot: Int) {
        guard !isRedeeming else { return }
        isRedeeming = true
        redemptionMessage = nil
        Task {
            let result = await store.redeemNextProjectSlot()
            isRedeeming = false
            switch result {
            case .success:
                redemptionMessage = "\(targetSlot)作品目の枠を解放しました。"
            case .failure(let error):
                redemptionError = error.userMessage
            }
        }
    }
}
