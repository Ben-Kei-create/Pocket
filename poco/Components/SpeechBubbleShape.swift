import SwiftUI

struct SpeechBubbleShape: Shape {
    // Archived classic shape. Kept with BubbleTexture for a one-line style rollback.
    func path(in rect: CGRect) -> Path {
        let tailHeight = min(14, rect.height * 0.18)
        let bubbleRect = CGRect(
            x: rect.minX,
            y: rect.minY,
            width: rect.width,
            height: rect.height - tailHeight
        )
        let radius = min(25, bubbleRect.height * 0.35)
        var path = Path(
            roundedRect: bubbleRect,
            cornerRadius: radius,
            style: .continuous
        )

        path.move(to: CGPoint(x: rect.maxX - 45, y: bubbleRect.maxY - 2))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - 16, y: rect.maxY),
            control: CGPoint(x: rect.maxX - 31, y: rect.maxY - 2)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - 22, y: bubbleRect.maxY - 16),
            control: CGPoint(x: rect.maxX - 17, y: bubbleRect.maxY - 7)
        )
        path.closeSubpath()
        return path
    }
}

struct BubbleView: View {
    let feedback: Feedback
    var compact = false
    var onSelectAuthor: ((Creator) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 3 : 10) {
            Text(feedback.message)
                .font(compact ? .system(size: 9.5, weight: .semibold) : .body.weight(.medium))
                .foregroundStyle(Color(uiColor: .label).opacity(0.86))
                .lineLimit(compact ? 2 : 5)
                .lineSpacing(compact ? 1 : 3)
                .minimumScaleFactor(0.82)

            authorControl
        }
        .padding(.horizontal, compact ? 15 : 18)
        .padding(.top, compact ? 12 : 16)
        .padding(.bottom, compact ? 12 : 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background {
            Image(BubbleArtworkStyle.active.textureAssetName)
                .resizable()
                .colorMultiply(PocoTheme.bubble(feedback.bubbleColor))
                .shadow(color: .black.opacity(0.055), radius: compact ? 5 : 9, y: 4)
        }
        .overlay(alignment: .topTrailing) {
            if feedback.creatorReceivedAt != nil {
                Image(systemName: "sparkles")
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .frame(width: compact ? 18 : 24, height: compact ? 18 : 24)
                    .background(.yellow, in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 1))
                    .padding(compact ? 5 : 8)
                    .accessibilityLabel("作者にとどきました")
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: compact ? 20 : 28, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var authorControl: some View {
        if let creator = feedback.senderCreator, let onSelectAuthor {
            Button {
                onSelectAuthor(creator)
            } label: {
                authorLabel
            }
            .buttonStyle(.plain)
            .accessibilityHint("公開プロフィールを開きます")
        } else {
            authorLabel
        }
    }

    private var authorLabel: some View {
        HStack(spacing: compact ? 4 : 6) {
            feedbackAvatar

            Text(feedback.nickname)
                .font(compact ? .system(size: 8, weight: .medium) : .caption)
                .foregroundStyle(Color(uiColor: .secondaryLabel))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("投稿者、\(feedback.nickname)")
    }

    @ViewBuilder
    private var feedbackAvatar: some View {
        if feedback.senderAvatarName != nil || feedback.senderAvatarURL != nil {
            ProfileAvatarView(
                creator: Creator(
                    id: feedback.senderID ?? feedback.id,
                    name: feedback.nickname,
                    avatarName: feedback.senderAvatarName,
                    avatarURL: feedback.senderAvatarURL
                ),
                size: compact ? 14 : 23
            )
        } else {
            Text(String(feedback.nickname.prefix(1)))
                .font(.system(size: compact ? 7 : 10, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: compact ? 14 : 23, height: compact ? 14 : 23)
                .background(.black.opacity(0.22), in: Circle())
        }
    }
}
