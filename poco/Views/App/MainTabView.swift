import SwiftUI

struct MainTabView: View {
    @Environment(PocoStore.self) private var store
    @State private var showsMembership = false

    var body: some View {
        @Bindable var store = store

        TabView(selection: $store.selectedTab) {
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
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !store.isPocoMember {
                PocoAdBanner {
                    showsMembership = true
                }
            }
        }
        .sheet(isPresented: $showsMembership) {
            PocoMembershipView()
        }
    }
}
