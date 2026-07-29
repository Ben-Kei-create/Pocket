import SwiftUI

struct ContentView: View {
    @Environment(PocoStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("poco.hasCompletedWelcome") private var hasCompletedWelcome = false
    @State private var showsDailyLoginBonus = false
    @State private var presentedLoginBonusDay: String?
    @State private var defersDailyLoginBonusForProjectLink = false
    @State private var deferredProjectWasPresented = false

    var body: some View {
        Group {
            if hasCompletedWelcome {
                MainTabView()
            } else {
                WelcomeView(
                    onContinue: completeWelcome,
                    onOpenProjectURL: { url in
                        openProjectURL(url, completesWelcome: true)
                    }
                )
                .transition(.opacity)
            }
        }
        .environment(\.font, PocoTypography.font(.body))
        .background(PocoTheme.background)
        .onOpenURL { url in
            openProjectURL(url, completesWelcome: true)
        }
        .task {
            await store.load()
            await presentDailyLoginBonusIfNeeded()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await presentDailyLoginBonusIfNeeded() }
        }
        .onChange(of: store.accountStatus) { _, status in
            guard status == .registered else { return }
            Task { await presentDailyLoginBonusIfNeeded() }
        }
        .onChange(of: hasCompletedWelcome) { _, isCompleted in
            guard isCompleted else { return }
            Task { await presentDailyLoginBonusIfNeeded() }
        }
        .onChange(of: store.selectedTab) { _, tab in
            guard tab == .home else { return }
            Task { await presentDailyLoginBonusIfNeeded() }
        }
        .onChange(of: store.homePath) { _, path in
            if defersDailyLoginBonusForProjectLink {
                if !path.isEmpty {
                    deferredProjectWasPresented = true
                } else if deferredProjectWasPresented {
                    finishDeferredProjectLanding()
                }
            } else if path.isEmpty {
                Task { await presentDailyLoginBonusIfNeeded() }
            }
        }
        .onChange(of: store.isResolvingDeepLink) { _, isResolving in
            guard !isResolving, store.homePath.isEmpty else { return }
            if defersDailyLoginBonusForProjectLink {
                finishDeferredProjectLanding()
            } else {
                Task { await presentDailyLoginBonusIfNeeded() }
            }
        }
        .sheet(isPresented: $showsDailyLoginBonus) {
            NavigationStack {
                MemberRewardCenterView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("閉じる") {
                                showsDailyLoginBonus = false
                            }
                        }
                    }
            }
        }
    }

    private func completeWelcome() {
        withAnimation(.easeInOut(duration: 0.35)) {
            hasCompletedWelcome = true
        }
    }

    private func openProjectURL(_ url: URL, completesWelcome: Bool) {
        guard ProjectDeepLink.projectID(from: url) != nil else { return }

        // A QR / Universal Link landing is the user's primary intent. Never
        // cover the destination with the daily reward sheet.
        defersDailyLoginBonusForProjectLink = true
        deferredProjectWasPresented = false
        if showsDailyLoginBonus {
            showsDailyLoginBonus = false
            presentedLoginBonusDay = nil
        }
        if completesWelcome {
            completeWelcome()
        }

        guard store.open(url: url) else {
            finishDeferredProjectLanding()
            return
        }
        deferredProjectWasPresented = !store.homePath.isEmpty
    }

    private func finishDeferredProjectLanding() {
        defersDailyLoginBonusForProjectLink = false
        deferredProjectWasPresented = false
        Task { await presentDailyLoginBonusIfNeeded() }
    }

    @MainActor
    private func presentDailyLoginBonusIfNeeded() async {
        guard hasCompletedWelcome,
              store.accountStatus == .registered,
              store.selectedTab == .home,
              store.homePath.isEmpty,
              !defersDailyLoginBonusForProjectLink,
              !showsDailyLoginBonus else { return }

        let today = PocoCalendar.todayKey()
        guard presentedLoginBonusDay != today else { return }

        await store.loadMemberRewards()
        guard case .loaded = store.memberRewardLoadState,
              store.memberRewardSnapshot.canClaimToday,
              store.selectedTab == .home,
              store.homePath.isEmpty,
              !store.isResolvingDeepLink,
              !defersDailyLoginBonusForProjectLink else { return }

        presentedLoginBonusDay = today
        showsDailyLoginBonus = true
    }
}

#Preview {
    ContentView()
        .environment(PocoStore())
}
