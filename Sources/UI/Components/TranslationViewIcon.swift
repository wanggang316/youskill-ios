import SwiftUI

/// Toolbar glyph for the reader's translation control: a globe behind an "A" bubble (original)
/// and a "文" bubble (translation). The bubbles of the current view are filled.
struct TranslationViewIcon: View {
    /// `nil` before a translation exists; no bubble is filled.
    let view: TranslationView?

    private static let size = CGSize(width: 28, height: 24)
    private static let lineWidth: CGFloat = 1.3

    var body: some View {
        ZStack(alignment: .topLeading) {
            globe
            bubble(
                CGRect(x: 0.7, y: 0.7, width: 14, height: 12.5),
                tail: .bottom,
                letter: "A",
                isFilled: view == .original || view == .bilingual
            )
            bubble(
                CGRect(x: 13.3, y: 10.8, width: 14, height: 12.5),
                tail: .top,
                letter: "文",
                isFilled: view == .translation || view == .bilingual
            )
        }
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
        .accessibilityHidden(true)
    }

    private var globe: some View {
        let center = CGPoint(x: 14, y: 12)
        let radius: CGFloat = 8
        return Path { path in
            path.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            path.addEllipse(in: CGRect(x: center.x - 3.5, y: center.y - radius, width: 7, height: radius * 2))
            path.move(to: CGPoint(x: center.x - radius, y: center.y))
            path.addLine(to: CGPoint(x: center.x + radius, y: center.y))
        }
        .stroke(.foreground, lineWidth: Self.lineWidth)
    }

    private func bubble(_ rect: CGRect, tail: SpeechBubble.Tail, letter: String, isFilled: Bool) -> some View {
        let shape = SpeechBubble(tail: tail)
        let body = shape.bodyRect(in: CGRect(origin: .zero, size: rect.size))
        return ZStack(alignment: .topLeading) {
            if isFilled {
                shape.fill(.foreground)
            } else {
                // Opaque so the globe does not show through an empty bubble.
                shape.fill(Color.white)
            }
            shape.stroke(.foreground, style: StrokeStyle(lineWidth: Self.lineWidth, lineJoin: .round))
            Text(letter)
                .font(.system(size: 7.5, weight: .bold))
                .foregroundStyle(isFilled ? AnyShapeStyle(Color.white) : AnyShapeStyle(ForegroundStyle()))
                .fixedSize()
                .position(x: body.midX, y: body.midY)
        }
        .frame(width: rect.width, height: rect.height)
        .offset(x: rect.minX, y: rect.minY)
    }
}

private struct SpeechBubble: Shape {
    enum Tail {
        /// Tail on the bottom edge near the trailing corner, pointing down.
        case bottom
        /// Tail on the top edge near the leading corner, pointing up.
        case top
    }

    let tail: Tail

    func bodyRect(in rect: CGRect) -> CGRect {
        let tailHeight = rect.height * 0.22
        switch tail {
        case .bottom:
            return CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height - tailHeight)
        case .top:
            return CGRect(x: rect.minX, y: rect.minY + tailHeight, width: rect.width, height: rect.height - tailHeight)
        }
    }

    func path(in rect: CGRect) -> Path {
        let body = bodyRect(in: rect)
        let radius = min(body.width, body.height) * 0.22
        var path = Path()

        path.move(to: CGPoint(x: body.minX + radius, y: body.minY))
        if tail == .top {
            path.addLine(to: CGPoint(x: body.minX + body.width * 0.18, y: body.minY))
            path.addLine(to: CGPoint(x: body.minX + body.width * 0.14, y: rect.minY))
            path.addLine(to: CGPoint(x: body.minX + body.width * 0.40, y: body.minY))
        }
        path.addArc(
            tangent1End: CGPoint(x: body.maxX, y: body.minY),
            tangent2End: CGPoint(x: body.maxX, y: body.maxY),
            radius: radius
        )
        path.addArc(
            tangent1End: CGPoint(x: body.maxX, y: body.maxY),
            tangent2End: CGPoint(x: body.minX, y: body.maxY),
            radius: radius
        )
        if tail == .bottom {
            path.addLine(to: CGPoint(x: body.minX + body.width * 0.82, y: body.maxY))
            path.addLine(to: CGPoint(x: body.minX + body.width * 0.86, y: rect.maxY))
            path.addLine(to: CGPoint(x: body.minX + body.width * 0.60, y: body.maxY))
        }
        path.addArc(
            tangent1End: CGPoint(x: body.minX, y: body.maxY),
            tangent2End: CGPoint(x: body.minX, y: body.minY),
            radius: radius
        )
        path.addArc(
            tangent1End: CGPoint(x: body.minX, y: body.minY),
            tangent2End: CGPoint(x: body.maxX, y: body.minY),
            radius: radius
        )
        path.closeSubpath()
        return path
    }
}
