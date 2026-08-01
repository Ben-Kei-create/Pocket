import SwiftUI

struct MainTabView: View {
    @Environment(PocoStore.self) private var store
    @State private var showsRegistration = false
    @AppStorage("poco.announcements.lastSeenAt") private var lastSeenAnnouncementTimestamp = 0.0

    var body: some View {
        ZStack {
            TabView(selection: tabSelection) {
                HomeView()
                    .tag(AppTab.home)

                CreatorDashboardView()
                    .tag(AppTab.create)

                NotificationHubView()
                    .tag(AppTab.notifications)

                MyPageView()
                    .tag(AppTab.myPage)
            }
            .toolbar(.hidden, for: .tabBar)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                PocoTabBar(
                    selection: store.selectedTab,
                    notificationCount: totalUnreadNotificationCount,
                    onSelect: { newTab in
                        selectTab(newTab)
                    }
                )
            }

            if let guide = store.onboardingGuideRequest {
                PocoRoleOnboardingView(guide: guide) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        store.completeOnboarding(guide)
                    }
                }
                .zIndex(10)
            }
        }
        .sheet(isPresented: $showsRegistration) {
            RegistrationGateView {
                store.selectedTab = .create
            }
        }
        .task(id: store.onboardingStateToken) {
            store.presentOnboardingIfNeeded()
        }
    }

    private var tabSelection: Binding<AppTab> {
        Binding(
            get: { store.selectedTab },
            set: { newTab in
                selectTab(newTab)
            }
        )
    }

    private func selectTab(_ newTab: AppTab) {
        if newTab == .create && !store.canCreateProjects {
            showsRegistration = true
        } else {
            store.selectedTab = newTab
        }
    }

    private var totalUnreadNotificationCount: Int {
        let unreadAnnouncements = store.announcements.lazy.filter {
            $0.publishedAt.timeIntervalSince1970 > lastSeenAnnouncementTimestamp
        }.count
        return store.unreadNotificationCount + unreadAnnouncements
    }
}
