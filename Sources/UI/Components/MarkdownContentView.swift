import MarkdownUI
import SwiftUI

struct MarkdownContentView: View {
    let description: String?
    var translatedDescription: String? = nil
    let markdown: String
    /// When set, the body renders as stacked original and translated blocks instead of `markdown`.
    var bilingualSegments: [BilingualSegment]? = nil
    let baseURL: URL?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let description, !description.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(description)
                        if let translatedDescription, !translatedDescription.isEmpty {
                            Text(translatedDescription)
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                if let bilingualSegments {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(Array(bilingualSegments.enumerated()), id: \.offset) { _, segment in
                            segmentView(segment)
                        }
                    }
                    .accessibilityIdentifier("detail.bilingual")
                } else {
                    markdownView(markdown)
                }
            }
            .font(.body)
            .frame(maxWidth: 760, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity)
        }
        .background(AppTheme.cardBackground)
    }

    @ViewBuilder
    private func segmentView(_ segment: BilingualSegment) -> some View {
        switch segment {
        case let .original(source), let .translated(source), let .list(source):
            markdownView(source)
        case let .stacked(original, translated):
            markdownView(original)
            markdownView(translated)
        case let .heading(level, original, translated):
            // The translation is the heading's second line. Sizes follow MarkdownUI's GitHub theme (16pt base).
            VStack(alignment: .leading, spacing: 4) {
                Text(Self.inlineMarkdown(original))
                Text(Self.inlineMarkdown(translated))
                if level <= 2 {
                    Divider()
                        .padding(.top, 4)
                }
            }
            .font(.system(size: 16 * Self.headingScale(level), weight: .semibold))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func markdownView(_ source: String) -> some View {
        Markdown(source, baseURL: baseURL, imageBaseURL: baseURL)
            .markdownTheme(.gitHub)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static func inlineMarkdown(_ text: String) -> AttributedString {
        (try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(text)
    }

    private static func headingScale(_ level: Int) -> CGFloat {
        [2, 1.5, 1.25, 1, 0.875, 0.85][min(max(level, 1), 6) - 1]
    }
}
