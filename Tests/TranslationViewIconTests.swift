import SwiftUI
import Testing
@testable import YouSkill

/// The toolbar shows `TranslationViewIcon.template` as a template image, so its alpha is the icon:
/// an empty bubble has to be transparent, with the globe cut away beneath it, and a filled bubble's
/// letter has to be a hole in the fill.
@MainActor
@Suite
struct TranslationViewIconTests {
    // Icon coordinates in points. Each sample is at least 1pt from any outline or letter.
    /// Inside the "A" bubble, left of the letter.
    private let insideOriginal = CGPoint(x: 3.0, y: 5.5)
    /// Inside the "A" bubble, on the line where the globe's meridian would run.
    private let globeUnderOriginal = CGPoint(x: 11.69, y: 6.0)
    /// Inside the "文" bubble, left of the letter.
    private let insideTranslation = CGPoint(x: 15.0, y: 18.4)
    /// On the globe's outline, clear of both bubbles.
    private let visibleGlobe = CGPoint(x: 19.66, y: 6.34)
    /// Bubble bodies inset 1.5pt, clear of the outlines; only the letter is inside.
    private let originalBody = CGRect(x: 2.2, y: 2.2, width: 11, height: 6.75)
    private let translationBody = CGRect(x: 14.8, y: 15.05, width: 11, height: 6.75)

    @Test
    func emptyBubblesAreHollowWithTheGlobeCutAway() throws {
        let icon = try RenderedIcon(view: nil)

        #expect(icon.alpha(at: insideOriginal) == 0)
        #expect(icon.alpha(at: globeUnderOriginal) == 0)
        #expect(icon.alpha(at: insideTranslation) == 0)
        #expect(icon.alpha(at: visibleGlobe) > 128)
        #expect(icon.transparentFraction(in: originalBody) > 0.5)
        #expect(icon.transparentFraction(in: translationBody) > 0.5)
    }

    @Test
    func filledBubblesCutTheLetterOut() throws {
        let icon = try RenderedIcon(view: .bilingual)

        for body in [originalBody, translationBody] {
            let transparent = icon.transparentFraction(in: body)
            #expect(transparent > 0.03, "The letter is a hole in the fill")
            #expect(transparent < 0.5, "The rest of the bubble is filled")
        }
    }

    @Test
    func currentViewFillsOnlyItsBubbles() throws {
        let original = try RenderedIcon(view: .original)
        #expect(original.alpha(at: insideOriginal) > 128)
        #expect(original.alpha(at: insideTranslation) == 0)

        let translation = try RenderedIcon(view: .translation)
        #expect(translation.alpha(at: insideOriginal) == 0)
        #expect(translation.alpha(at: globeUnderOriginal) == 0)
        #expect(translation.alpha(at: insideTranslation) > 128)

        let bilingual = try RenderedIcon(view: .bilingual)
        #expect(bilingual.alpha(at: insideOriginal) > 128)
        #expect(bilingual.alpha(at: insideTranslation) > 128)
    }
}

@MainActor
private struct RenderedIcon {
    private enum RenderError: Error {
        case noImage
        case noContext
    }

    private static let scale: CGFloat = 3
    private let pixels: [UInt8]
    private let width: Int
    private let height: Int

    init(view: TranslationView?) throws {
        guard let image = TranslationViewIcon.template(for: view, scale: Self.scale) else {
            throw RenderError.noImage
        }

        // Redraw into a known RGBA layout; row 0 is the top of the icon.
        let width = image.width
        let height = image.height
        var buffer = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = buffer.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(
                data: bytes.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { throw RenderError.noContext }
        pixels = buffer
        self.width = width
        self.height = height
    }

    func alpha(at point: CGPoint) -> UInt8 {
        let x = Int(point.x * Self.scale)
        let y = Int(point.y * Self.scale)
        return pixels[(y * width + x) * 4 + 3]
    }

    /// Share of nearly transparent pixels in a rect given in points.
    func transparentFraction(in rect: CGRect) -> Double {
        let xs = Int(rect.minX * Self.scale) ..< min(Int(rect.maxX * Self.scale), width)
        let ys = Int(rect.minY * Self.scale) ..< min(Int(rect.maxY * Self.scale), height)
        var transparent = 0
        for y in ys {
            for x in xs where pixels[(y * width + x) * 4 + 3] < 32 {
                transparent += 1
            }
        }
        return Double(transparent) / Double(xs.count * ys.count)
    }
}
