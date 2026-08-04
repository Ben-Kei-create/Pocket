import SwiftUI

struct ProjectImageGalleryView: View {
    @Environment(\.dismiss) private var dismiss

    let project: Project
    @State private var selectedIndex = 0

    private var images: [URL] {
        project.artworkURLs
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $selectedIndex) {
                ForEach(Array(images.enumerated()), id: \.offset) { index, url in
                    ProjectGalleryPage(url: url, title: project.title)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .pocoFont(.headline, weight: .bold)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(.black.opacity(0.52), in: Circle())
                    }
                    .accessibilityLabel("画像を閉じる")

                    Spacer()

                    if images.count > 1 {
                        Text("\(selectedIndex + 1) / \(images.count)")
                            .pocoFont(.subheadline, weight: .medium)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 13)
                            .frame(height: 36)
                            .background(.black.opacity(0.52), in: Capsule())
                            .accessibilityLabel("\(images.count)枚中\(selectedIndex + 1)枚目")
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)

                Spacer()

                if images.count > 1 {
                    HStack(spacing: 7) {
                        ForEach(images.indices, id: \.self) { index in
                            Capsule()
                                .fill(index == selectedIndex ? .white : .white.opacity(0.38))
                                .frame(width: index == selectedIndex ? 18 : 7, height: 7)
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: selectedIndex)
                    .padding(.bottom, 18)
                    .accessibilityHidden(true)
                }
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden()
    }
}

private struct ProjectGalleryPage: View {
    let url: URL
    let title: String

    var body: some View {
        SecureRemoteImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .empty:
                ProgressView()
                    .tint(.white)
                    .controlSize(.large)
            case .failure:
                ContentUnavailableView(
                    "画像を読み込めませんでした",
                    systemImage: "photo.badge.exclamationmark"
                )
                .foregroundStyle(.white)
            }
        }
        .padding(.vertical, 72)
        .accessibilityLabel("\(title)の作品画像")
    }
}
