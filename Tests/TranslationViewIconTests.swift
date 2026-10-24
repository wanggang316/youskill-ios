import SwiftUI
import Testing
@testable import YouSkill

/// The toolbar's glass draws light fills translucently, so the icon must never rely on a fill to hide
/// the globe: an empty bubble has to be empty, with the globe cut away beneath it.
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

    @Test
    func emptyBubblesAreHollowWithTheGlobeCutAway() throws {
        let icon = try RenderedIcon(view: nil)

        #expect(icon.alpha(at: insideOriginal) == 0)
        #expect(icon.alpha(at: globeUnderOriginal) == 0)
        #expect(icon.alpha(at: insideTranslation) == 0)
        #expect(icon.alpha(at: visibleGlobe) > 128)
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

    init(view: TranslationView?) throws {
        let renderer = ImageRenderer(content: TranslationViewIcon(view: view))
        renderer.scale = Self.scale
        guard let image = renderer.cgImage else { throw RenderError.noImage }

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
    }

    func alpha(at point: CGPoint) -> UInt8 {
        let x = Int(point.x * Self.scale)
        let y = Int(point.y * Self.scale)
        return pixels[(y * width + x) * 4 + 3]
    }
}
