import SwiftUI

struct ProjectCard: View {
    let project: Project

    var body: some View {
        HStack(spacing: 14) {
            ProjectArtworkThumbnail(project: project)
                .frame(width: 108, height: 118)
                .clipShape(RoundedRectangle(cornerRadius: PocoTheme.cornerSmall, style: .continuous))

            VStack(alignment: .leading, spacing: 7) {
                Text(project.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text("\(project.category.creatorPrefix)：\(project.creator.name)")
                    .font(.caption)
                    .foregroundStyle(PocoTheme.secondaryText)
                    .lineLimit(1)

                Text(project.description)
                    .font(.caption)
                    .foregroundStyle(PocoTheme.secondaryText)
                    .lineLimit(2)
                    .lineSpacing(2)

                Spacer(minLength: 0)

                HStack {
                    AvatarStack(names: ["は", "れ", "そ"])
                    Spacer()
                    Label(project.feedbackCount.formatted(), systemImage: "bubble.left")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(PocoTheme.secondaryText)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PocoTheme.primary)
                }
            }
            .padding(.vertical, 2)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 138, alignment: .leading)
        .pocoCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(project.title)、\(project.creator.name)、感想\(project.feedbackCount)件")
    }
}

struct ProjectArtworkThumbnail: View {
    let project: Project

    var body: some View {
        if let imageURL = project.imageURL {
            AsyncImage(
                url: imageURL,
                transaction: Transaction(animation: .easeInOut(duration: 0.2))
            ) { phase in
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
                @unknown default:
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
                    .font(.system(size: 9, weight: .bold, design: .rounded))
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
        case .other: [PocoTheme.bubble(.yellow), PocoTheme.primary.opacity(0.8)]
        }
    }
}
