import SwiftUI

/// Toolbar glyph for the reader's translation control: a globe behind an "A" bubble (original)
/// and a "文" bubble (translation). The bubbles of the current view are filled.
///
/// Drawn as a one-color template, like an SF Symbol. The toolbar's glass renders light fills
/// translucently, so instead of covering the globe with a white fill, the globe is cut away
/// under each bubble, empty bubbles are hollow, and a filled bubble's letter is cut out of it.
struct TranslationViewIcon: View {
    /// `nil` before a translation exists; no bubble is filled.
    let view: TranslationView?

    private static let size = CGSize(width: 28, height: 24)
    private static let originalBubble = CGRect(x: 0.7, y: 0.7, width: 14, height: 12.5)
    private static let translationBubble = CGRect(x: 13.3, y: 10.8, width: 14, height: 12.5)
    private static let lineWidth: CGFloat = 1.3
    /// Clear space between the globe and each bubble outline.
    private static let gap: CGFloat = 1

    var body: some View {
        ZStack(alignment: .topLeading) {
            globe
            knockout(Self.originalBubble, tail: .bottom)
            knockout(Self.translationBubble, tail: .top)
            bubble(
                Self.originalBubble,
                tail: .bottom,
                letter: "A",
                isFilled: view == .original || view == .bilingual
            )
            bubble(
                Self.translationBubble,
                tail: .top,
                letter: "文",
                isFilled: view == .translation || view == .bilingual
            )
        }
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
        // Confines the destination-out cutouts to the icon so they do not punch through the toolbar.
        .compositingGroup()
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

    /// Erases the globe under a bubble and in a `gap`-wide band around its outline.
    private func knockout(_ rect: CGRect, tail: SpeechBubble.Tail) -> some View {
        let shape = SpeechBubble(tail: tail)
        return ZStack {
            shape.fill(.black)
            shape.stroke(.black, style: StrokeStyle(lineWidth: Self.lineWidth + 2 * Self.gap, lineJoin: .round))
        }
        .frame(width: rect.width, height: rect.height)
        .offset(x: rect.minX, y: rect.minY)
        .blendMode(.destinationOut)
    }

    private func bubble(_ rect: CGRect, tail: SpeechBubble.Tail, letter: String, isFilled: Bool) -> some View {
        let shape = SpeechBubble(tail: tail)
        let body = shape.bodyRect(in: CGRect(origin: .zero, size: rect.size))
        let label = Text(letter)
            .font(.system(size: 7.5, weight: .bold))
            .fixedSize()
            .position(x: body.midX, y: body.midY)
        return ZStack(alignment: .topLeading) {
            if isFilled {
                shape.fill(.foreground)
            }
            shape.stroke(.foreground, style: StrokeStyle(lineWidth: Self.lineWidth, lineJoin: .round))
            if isFilled {
                label
                    .foregroundStyle(.black)
                    .blendMode(.destinationOut)
            } else {
                label
            }
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
