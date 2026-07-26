import SwiftUI

struct MainTabView: View {
    @Environment(PocoStore.self) private var store

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
    }
}
