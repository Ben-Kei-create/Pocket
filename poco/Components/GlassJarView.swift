import SwiftUI

struct GlassJarShape: Shape {
    func path(in rect: CGRect) -> Path {
        let neckInset = rect.width * 0.095
        let shoulderY = rect.minY + rect.height * 0.095
        let bottomRadius = min(36, rect.width * 0.11)

        var path = Path()
        path.move(to: CGPoint(x: rect.minX + neckInset, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - neckInset, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: shoulderY),
            control: CGPoint(x: rect.maxX - neckInset * 0.15, y: rect.minY + 4)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRadius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - bottomRadius, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + bottomRadius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - bottomRadius),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: shoulderY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + neckInset, y: rect.minY),
            control: CGPoint(x: rect.minX + neckInset * 0.15, y: rect.minY + 4)
        )
        path.closeSubpath()
        return path
    }
}

struct GlassJarView<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Ellipse()
                    .fill(.black.opacity(0.055))
                    .frame(width: proxy.size.width * 0.88, height: 28)
                    .blur(radius: 7)
                    .position(x: proxy.size.width / 2, y: proxy.size.height - 1)

                GlassJarShape()
                    .fill(.white.opacity(0.24))
                    .background(.ultraThinMaterial.opacity(0.27))
                    .clipShape(GlassJarShape())

                content()
                    .padding(.horizontal, 12)
                    .padding(.top, 22)
                    .padding(.bottom, 12)
                    .clipShape(GlassJarShape())

                GlassJarShape()
                    .stroke(PocoTheme.glassStroke, lineWidth: 2)

                RoundedRectangle(cornerRadius: 3)
                    .fill(.white.opacity(0.72))
                    .frame(width: 4, height: proxy.size.height * 0.64)
                    .blur(radius: 0.6)
                    .position(x: 22, y: proxy.size.height * 0.47)

                Capsule()
                    .fill(.white.opacity(0.62))
                    .frame(width: proxy.size.width * 0.58, height: 4)
                    .position(x: proxy.size.width / 2, y: 10)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("感想のフキダシがたまったガラス瓶")
    }
}

struct BubblePileView: View {
    let feedbacks: [Feedback]
    var isInteractive = false
    var onSelect: ((Feedback) -> Void)?

    var body: some View {
        GeometryReader { proxy in
            ForEach(Array(feedbacks.prefix(12).enumerated()), id: \.element.id) { index, feedback in
                let width = bubbleWidth(index: index, availableWidth: proxy.size.width)

                BubbleView(feedback: feedback, compact: true)
                    .frame(width: width, height: 76)
                    .rotationEffect(.degrees(rotation(index)))
                    .position(position(index: index, size: proxy.size))
                    .zIndex(Double(index))
                    .onTapGesture {
                        guard isInteractive else { return }
                        onSelect?(feedback)
                    }
                    .accessibilityAddTraits(isInteractive ? .isButton : [])
            }
        }
    }

    private func bubbleWidth(index: Int, availableWidth: CGFloat) -> CGFloat {
        min(max(availableWidth * (index.isMultiple(of: 4) ? 0.35 : 0.40), 105), 150)
    }

    private func position(index: Int, size: CGSize) -> CGPoint {
        let column = index % 3
        let row = index / 3
        let xFactors: [CGFloat] = [0.19, 0.50, 0.81]
        let xJitter: [CGFloat] = [-3, 7, -5, 4]
        let yJitter: [CGFloat] = [0, -7, 5, -3, 4]
        return CGPoint(
            x: size.width * xFactors[column] + xJitter[index % xJitter.count],
            y: size.height - 45 - CGFloat(row) * 69 + yJitter[index % yJitter.count]
        )
    }

    private func rotation(_ index: Int) -> Double {
        [-4.0, 2.5, -1.5, 3.5, -2.5][index % 5]
    }
}
