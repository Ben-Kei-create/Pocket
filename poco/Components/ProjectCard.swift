import SwiftUI

struct ProjectCard: View {
    let project: Project

    var body: some View {
        HStack(spacing: 14) {
            ProjectArtworkThumbnail(project: project)
                .frame(width: 108, height: 118)
                .clipShape(RoundedRectangle(cornerRadius: PocoTheme.cornerSmall, style: .continuous))

            VStack(alignment: .leading, spacing: 7) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 5) {
                        ProjectRelationshipBadge(project: project, compact: true)
                        if project.purpose == .event {
                            ProjectPurposeBadge(purpose: project.purpose, compact: true)
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        ProjectRelationshipBadge(project: project, compact: true)
                        if project.purpose == .event {
                            ProjectPurposeBadge(purpose: project.purpose, compact: true)
                        }
                    }
                }

                if project.isContentLocked {
                    Label("年齢制限あり", systemImage: "lock.fill")
                        .pocoFont(.caption2, weight: .medium)
                        .foregroundStyle(PocoTheme.primary)
                }

                Text(project.title)
                    .pocoFont(.headline, weight: .medium)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text("\(project.category.creatorPrefix)：\(project.creator.name)")
                    .pocoFont(.caption)
                    .foregroundStyle(PocoTheme.secondaryText)
                    .lineLimit(1)

                Text(project.description)
                    .pocoFont(.caption)
                    .foregroundStyle(PocoTheme.secondaryText)
                    .lineLimit(2)
                    .lineSpacing(2)

                Spacer(minLength: 0)

                HStack {
                    AvatarStack(names: ["は", "れ", "そ"])
                    Spacer()
                    Label(project.feedbackCount.formatted(), systemImage: "bubble.left")
                        .pocoFont(.caption, weight: .medium)
                        .foregroundStyle(PocoTheme.secondaryText)
                    Image(systemName: "chevron.right")
                        .pocoFont(.caption, weight: .bold)
                        .foregroundStyle(PocoTheme.primary)
                }
            }
            .padding(.vertical, 2)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 138, alignment: .leading)
        .pocoCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(project.title)、\(project.creator.name)、\(project.relationship.badgeTitle(verificationStatus: project.verificationStatus))、\(project.purpose.title)、感想\(project.feedbackCount)件"
        )
    }
}

struct ProjectRelationshipBadge: View {
    let project: Project
    var compact = false

    var body: some View {
        Label(
            project.relationship.badgeTitle(verificationStatus: project.verificationStatus),
            systemImage: badgeSymbol
        )
        .pocoFont(compact ? .caption2 : .caption, weight: .medium)
        .foregroundStyle(badgeColor)
        .padding(.horizontal, compact ? 7 : 9)
        .padding(.vertical, compact ? 3 : 5)
        .background(badgeColor.opacity(0.10), in: Capsule())
        .lineLimit(1)
        .accessibilityLabel(
            "作品ページの区分、\(project.relationship.badgeTitle(verificationStatus: project.verificationStatus))"
        )
    }

    private var badgeSymbol: String {
        if project.verificationStatus == .verified, project.relationship != .fan {
            return "checkmark.seal.fill"
        }
        return project.relationship.symbolName
    }

    private var badgeColor: Color {
        switch project.relationship {
        case .creator: PocoTheme.primary
        case .authorized: .blue
        case .fan: .purple
        }
    }
}

struct ProjectPurposeBadge: View {
    let purpose: ProjectPurpose
    var compact = false

    var body: some View {
        Label(purpose.title, systemImage: purpose.symbolName)
            .pocoFont(compact ? .caption2 : .caption, weight: .medium)
            .foregroundStyle(.orange)
            .padding(.horizontal, compact ? 7 : 9)
            .padding(.vertical, compact ? 3 : 5)
            .background(Color.orange.opacity(0.10), in: Capsule())
            .lineLimit(1)
            .accessibilityLabel("ページの使い方、\(purpose.title)")
    }
}

struct ProjectArtworkThumbnail: View {
    let project: Project

    var body: some View {
        if project.isContentLocked {
            ProjectArtworkView(category: project.category)
                .overlay {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                    VStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                            .pocoFont(.title3)
                        Text("年齢制限")
                            .pocoFont(.caption2, weight: .medium)
                    }
                    .foregroundStyle(PocoTheme.secondaryText)
                }
                .accessibilityLabel("年齢制限により画像を非表示")
        } else if let imageURL = project.imageURL {
            SecureRemoteImage(url: imageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .transition(.opacity)
                case .empty:
                    ProjectArtworkView(category: project.category)
                        .overlay {
                            ProgressView()
                                .controlSize(.small)
                        }
                case .failure:
                    ProjectArtworkView(category: project.category)
                }
            }
        } else {
            ProjectArtworkView(category: project.category)
        }
    }
}

struct AvatarStack: View {
    let names: [String]

    var body: some View {
        HStack(spacing: -7) {
            ForEach(Array(names.enumerated()), id: \.offset) { index, name in
                Text(name)
                    .pocoFixedFont(size: 9, weight: .bold)
                    .foregroundStyle(.white)
                    .frame(width: 25, height: 25)
                    .background(PocoTheme.bubble(BubbleColor.allCases[index % BubbleColor.allCases.count]).opacity(0.95))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(.white, lineWidth: 2))
            }
        }
        .accessibilityHidden(true)
    }
}

struct ProjectArtworkView: View {
    let category: ProjectCategory

    var body: some View {
        ZStack {
            LinearGradient(colors: palette, startPoint: .topLeading, endPoint: .bottomTrailing)

            Circle()
                .fill(.white.opacity(0.42))
                .frame(width: 76, height: 76)
                .offset(x: -27, y: -34)

            Image(systemName: category.symbolName)
                .font(.system(size: 38, weight: .medium))
                .foregroundStyle(.white.opacity(0.96))
                .shadow(color: .black.opacity(0.08), radius: 6, y: 3)

            HStack(spacing: 5) {
                ForEach(0..<3) { _ in
                    Circle().fill(.white.opacity(0.65)).frame(width: 6, height: 6)
                }
            }
            .offset(y: 42)
        }
        .accessibilityHidden(true)
    }

    private var palette: [Color] {
        switch category {
        case .book: [PocoTheme.bubble(.mint), Color(red: 0.36, green: 0.66, blue: 0.52)]
        case .game: [PocoTheme.bubble(.blue), Color(red: 0.22, green: 0.70, blue: 0.82)]
        case .manga: [PocoTheme.bubble(.lavender), PocoTheme.bubble(.pink)]
        case .anime: [PocoTheme.bubble(.coral), PocoTheme.bubble(.yellow)]
        case .other: [PocoTheme.bubble(.yellow), PocoTheme.primary.opacity(0.8)]
        }
    }
}
