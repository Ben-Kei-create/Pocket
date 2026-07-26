import SwiftUI

struct ContentView: View {
    @Environment(PocoStore.self) private var store
    @AppStorage("poco.hasCompletedWelcome") private var hasCompletedWelcome = false

    var body: some View {
        Group {
            if hasCompletedWelcome {
                MainTabView()
            } else {
                WelcomeView {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        hasCompletedWelcome = true
                    }
                }
                .transition(.opacity)
            }
        }
        .background(PocoTheme.background)
        .onOpenURL { url in
            hasCompletedWelcome = true
            store.open(url: url)
        }
        .task {
            await store.load()
        }
    }
}

#Preview {
    ContentView()
        .environment(PocoStore())
}
