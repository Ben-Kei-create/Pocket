import SwiftUI

struct ProfileLinkIcon: View {
    let service: ProfileLinkService
    var size: CGFloat = 18

    var body: some View {
        Group {
            if service == .x {
                Text("𝕏")
                    .font(.system(size: size, weight: .semibold, design: .rounded))
            } else {
                Image(systemName: service.symbolName)
                    .font(.system(size: size, weight: .semibold))
            }
        }
        .foregroundStyle(iconColor)
        .accessibilityHidden(true)
    }

    private var iconColor: Color {
        switch service {
        case .x: .primary
        case .instagram: .purple
        case .youtube: .red
        case .tiktok: PocoTheme.bubble(.mint)
        case .website: PocoTheme.primary
        }
    }
}

struct ProfileSocialLinksView: View {
    let links: [ProfileSocialLink]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(links) { link in
                    Link(destination: link.url) {
                        VStack(spacing: 7) {
                            ProfileLinkIcon(service: link.service, size: 20)
                                .frame(width: 44, height: 44)
                                .background(PocoTheme.cardBackground, in: Circle())
                                .overlay {
                                    Circle()
                                        .stroke(Color.primary.opacity(0.07), lineWidth: 1)
                                }
                                .shadow(color: .black.opacity(0.05), radius: 8, y: 4)

                            Text(link.service.title)
                                .pocoFont(.caption2, weight: .medium)
                                .foregroundStyle(PocoTheme.secondaryText)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(link.service.title)を開く")
                    .accessibilityHint("外部サイトをSafariで開きます")
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 4)
        }
    }
}
