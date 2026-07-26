import SwiftUI

struct SpeechBubbleShape: Shape {
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

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 5 : 10) {
            Text(feedback.message)
                .font(compact ? .caption.weight(.medium) : .body.weight(.medium))
                .foregroundStyle(Color(uiColor: .label).opacity(0.86))
                .lineLimit(compact ? 3 : 5)
                .lineSpacing(compact ? 1 : 3)
                .minimumScaleFactor(0.82)

            HStack(spacing: 6) {
                Text(String(feedback.nickname.prefix(1)))
                    .font(.system(size: compact ? 8 : 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: compact ? 18 : 23, height: compact ? 18 : 23)
                    .background(.black.opacity(0.22), in: Circle())

                Text(feedback.nickname)
                    .font(compact ? .caption2 : .caption)
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, compact ? 12 : 18)
        .padding(.top, compact ? 10 : 16)
        .padding(.bottom, compact ? 15 : 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background {
            SpeechBubbleShape()
                .fill(PocoTheme.bubble(feedback.bubbleColor).opacity(0.92))
                .shadow(color: .black.opacity(0.055), radius: compact ? 5 : 9, y: 4)
        }
        .overlay {
            SpeechBubbleShape()
                .stroke(.white.opacity(0.42), lineWidth: 1)
        }
        .contentShape(SpeechBubbleShape())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(feedback.nickname)さんの感想、\(feedback.message)")
    }
}
