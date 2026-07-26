import SwiftUI

struct CreatorDashboardView: View {
    @Environment(PocoStore.self) private var store
    @State private var showsCreateProject = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("ことばが集まる場所をつくろう")
                            .font(.title2.weight(.bold))
                        Text("作品ごとのQRコードと感想を管理できます。")
                            .font(.subheadline)
                            .foregroundStyle(PocoTheme.secondaryText)
                    }
                    .padding(.top, 8)

                    Button {
                        showsCreateProject = true
                    } label: {
                        Label("新しい作品を作る", systemImage: "plus")
                    }
                    .buttonStyle(PocoPrimaryButtonStyle())
                    .padding(.vertical, 4)

                    Text("あなたの作品")
                        .font(.headline)
                        .padding(.top, 8)

                    ForEach(store.projects) { project in
                        CreatorProjectCard(project: project)
                    }
                }
                .padding(.horizontal, PocoTheme.pagePadding)
                .padding(.bottom, 24)
            }
            .background(PocoTheme.background)
            .navigationTitle("Create")
            .sheet(isPresented: $showsCreateProject) {
                CreateProjectView()
            }
        }
    }
}

private struct CreatorProjectCard: View {
    let project: Project

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 13) {
                ProjectArtworkView(category: project.category)
                    .frame(width: 66, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text(project.title)
                        .font(.headline)
                        .lineLimit(2)
                    Label("\(project.feedbackCount.formatted())件の感想", systemImage: "bubble.left")
                        .font(.caption)
                        .foregroundStyle(PocoTheme.secondaryText)
                }
                Spacer()
                QRCodeImage(data: project.deepLinkURL.absoluteString)
                    .frame(width: 54, height: 54)
                    .accessibilityLabel("作品のQRコード")
            }

            HStack(spacing: 8) {
                NavigationLink {
                    BubbleWallView(projectID: project.id)
                } label: {
                    Label("感想を見る", systemImage: "bubble.left.and.bubble.right")
                }
                .buttonStyle(.bordered)

                NavigationLink {
                    QRCodeView(project: project)
                } label: {
                    Label("QR", systemImage: "qrcode")
                }
                .buttonStyle(.bordered)

                ShareLink(item: project.deepLinkURL) {
                    Label("共有", systemImage: "link")
                }
                .buttonStyle(.bordered)
            }
            .font(.caption.weight(.semibold))
        }
        .padding(16)
        .pocoCard()
    }
}
