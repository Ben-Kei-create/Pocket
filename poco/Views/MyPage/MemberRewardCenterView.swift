import SwiftUI
import UIKit

struct MemberRewardCenterView: View {
    @Environment(PocoStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isClaiming = false
    @State private var awardedCoins: Int?

    private let dailyRewards = [3, 3, 5, 3, 5, 7, 15]

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                VStack(spacing: 7) {
                    PocoCharacterView(
                        size: 132,
                        expression: .star,
                        isInteractive: false
                    )
                    Text("おかえりなさい")
                        .pocoFont(.title2, weight: .bold)
                    Text("毎日ひらくと、小さなごほうびが届きます。")
                        .pocoFont(.subheadline)
                        .foregroundStyle(PocoTheme.secondaryText)
                        .multilineTextAlignment(.center)
                }

                loginCalendar

                Button {
                    claim()
                } label: {
                    if isClaiming {
                        ProgressView().tint(.white)
                    } else if let awardedCoins {
                        Label("⭐︎ \(awardedCoins) もらいました", systemImage: "checkmark")
                    } else if store.memberRewardSnapshot.canClaimToday {
                        Label("今日のごほうびを受け取る", systemImage: "gift.fill")
                    } else {
                        Label("今日は受け取り済み", systemImage: "checkmark.circle.fill")
                    }
                }
                .buttonStyle(PocoPrimaryButtonStyle())
                .disabled(
                    isClaiming
                        || awardedCoins != nil
                        || !store.memberRewardSnapshot.canClaimToday
                )
                .accessibilityHint("今日のログインボーナスをスターコインで受け取ります")

            }
            .padding(PocoTheme.pagePadding)
        }
        .background(PocoTheme.groupedBackground)
        .navigationTitle("ログインボーナス")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await store.loadMemberRewards()
            if store.memberRewardSnapshot.canClaimToday {
                claim()
            }
        }
    }

    private var loginCalendar: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(
                    "\(store.memberRewardSnapshot.loginStreak)日つづいています",
                    systemImage: "flame.fill"
                )
                .pocoFont(.headline, weight: .medium)
                .foregroundStyle(PocoTheme.primary)
                Spacer()
                StarCoinBadge(balance: store.starCoinBalance)
            }

            HStack(spacing: 7) {
                ForEach(dailyRewards.indices, id: \.self) { index in
                    let isCompleted = completedCycleDays.contains(index)
                    VStack(spacing: 6) {
                        Text("\(index + 1)")
                            .pocoFont(.caption2, weight: .medium)
                            .foregroundStyle(PocoTheme.secondaryText)
                        Image(systemName: isCompleted ? "checkmark.circle.fill" : "star.fill")
                            .foregroundStyle(isCompleted ? PocoTheme.primary : Color.yellow)
                        Text("\(dailyRewards[index])")
                            .pocoFont(.caption2, weight: .bold).monospacedDigit()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        isCompleted
                            ? PocoTheme.bubble(.pink).opacity(0.55)
                            : PocoTheme.cardBackground,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(
                        "\(index + 1)日目、スター\(dailyRewards[index])枚"
                            + (isCompleted ? "、達成済み" : "")
                    )
                }
            }

            Text("7日目まで進むと、また1日目から楽しめます。")
                .pocoFont(.caption)
                .foregroundStyle(PocoTheme.tertiaryText)
        }
        .padding(17)
        .pocoCard()
    }

    private var completedCycleDays: Set<Int> {
        guard store.memberRewardSnapshot.loginStreak > 0 else { return [] }
        let completed = ((store.memberRewardSnapshot.loginStreak - 1) % dailyRewards.count) + 1
        return Set(0..<completed)
    }

    private func claim() {
        guard !isClaiming else { return }
        isClaiming = true
        Task {
            let result = await store.claimDailyLoginBonus()
            isClaiming = false
            if case .success(let claim) = result, claim.claimed {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                withAnimation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.72)) {
                    awardedCoins = claim.awardedCoins
                }
            }
        }
    }
}

struct AchievementStampsView: View {
    @Environment(PocoStore.self) private var store

    var body: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 14
            ) {
                ForEach(AchievementStamp.allCases) { stamp in
                    stampCard(stamp)
                }
            }
            .padding(PocoTheme.pagePadding)
        }
        .background(PocoTheme.groupedBackground)
        .navigationTitle("達成スタンプ")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await store.loadMemberRewards()
        }
    }

    private func stampCard(_ stamp: AchievementStamp) -> some View {
        let isUnlocked = store.memberRewardSnapshot.unlockedStamps.contains(stamp)
        return VStack(spacing: 11) {
            ZStack {
                Image(stamp.artworkAssetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 88, height: 88)
                    .saturation(isUnlocked ? 1 : 0)
                    .opacity(isUnlocked ? 1 : 0.28)

                if !isUnlocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(PocoTheme.secondaryText)
                        .padding(10)
                        .background(.thinMaterial, in: Circle())
                }
            }
            Text(stamp.title)
                .pocoFont(.subheadline, weight: .bold)
                .multilineTextAlignment(.center)
            Text(stamp.detail)
                .pocoFont(.caption)
                .foregroundStyle(PocoTheme.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 188)
        .padding(13)
        .pocoCard(cornerRadius: PocoTheme.cornerSmall)
        .opacity(isUnlocked ? 1 : 0.62)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(stamp.title)、\(stamp.detail)、\(isUnlocked ? "達成済み" : "未達成")"
        )
    }
}
