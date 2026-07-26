import SwiftUI

struct MyPageView: View {
    @AppStorage("poco.hasCompletedWelcome") private var hasCompletedWelcome = true

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 16) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 58))
                            .foregroundStyle(PocoTheme.bubble(.lavender))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("そらのひつじ")
                                .font(.headline)
                            Text("Pocoメンバー")
                                .font(.caption)
                                .foregroundStyle(PocoTheme.secondaryText)
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section("Poco") {
                    Label("送った感想", systemImage: "bubble.left")
                    Label("いいねしたフキダシ", systemImage: "heart")
                    Label("通知", systemImage: "bell")
                }

                Section {
                    Button("Welcomeをもう一度見る") {
                        hasCompletedWelcome = false
                    }
                    .foregroundStyle(PocoTheme.primary)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("マイページ")
        }
    }
}
