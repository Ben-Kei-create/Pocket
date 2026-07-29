import SwiftUI

struct ContentView: View {
    @Environment(PocoStore.self) private var store
    @AppStorage("poco.hasCompletedWelcome") private var hasCompletedWelcome = false

    var body: some View {
        Group {
            if hasCompletedWelcome {
                MainTabView()
            } else {
                WelcomeView(
                    onContinue: completeWelcome,
                    onOpenProjectURL: { url in
                        completeWelcome()
                        store.open(url: url)
                    }
                )
                .transition(.opacity)
            }
        }
        .environment(\.font, PocoTypography.font(.body))
        .background(PocoTheme.background)
        .onOpenURL { url in
            hasCompletedWelcome = true
            store.open(url: url)
        }
        .task {
            await store.load()
        }
    }

    private func completeWelcome() {
        withAnimation(.easeInOut(duration: 0.35)) {
            hasCompletedWelcome = true
        }
    }
}

#Preview {
    ContentView()
        .environment(PocoStore())
}
