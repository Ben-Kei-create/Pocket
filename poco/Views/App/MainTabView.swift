import SwiftUI

struct MainTabView: View {
    @Environment(PocoStore.self) private var store
    @State private var showsRegistration = false

    var body: some View {
        ZStack {
            TabView(selection: tabSelection) {
                HomeView()
                    .tabItem {
                        Label("ホーム", systemImage: "house.fill")
                    }
                    .tag(AppTab.home)

                CreatorDashboardView()
                    .tabItem {
                        Label("作る", systemImage: "plus.circle.fill")
                    }
                    .tag(AppTab.create)

                MyPageView()
                    .tabItem {
                        Label("マイページ", systemImage: "person")
                    }
                    .tag(AppTab.myPage)
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
                if newTab == .create && !store.canCreateProjects {
                    showsRegistration = true
                } else {
                    store.selectedTab = newTab
                }
            }
        )
    }
}
