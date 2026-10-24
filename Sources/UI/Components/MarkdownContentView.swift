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
            // The translation reads as the heading's second line, so the first line drops its rule.
            VStack(alignment: .leading, spacing: 4) {
                Markdown(Self.heading(level: level, text: original), baseURL: baseURL, imageBaseURL: baseURL)
                    .markdownTheme(.gitHubHeadingWithoutRule)
                    .frame(maxWidth: .infinity, alignment: .leading)
                markdownView(Self.heading(level: level, text: translated))
            }
        }
    }

    private func markdownView(_ source: String) -> some View {
        Markdown(source, baseURL: baseURL, imageBaseURL: baseURL)
            .markdownTheme(.gitHub)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static func heading(level: Int, text: String) -> String {
        String(repeating: "#", count: min(max(level, 1), 6)) + " " + text
    }
}

private extension Theme {
    static var gitHubHeadingWithoutRule: Theme {
        Theme.gitHub
            .heading1 { configuration in
                configuration.label
                    .relativeLineSpacing(.em(0.125))
                    .markdownTextStyle {
                        FontWeight(.semibold)
                        FontSize(.em(2))
                    }
            }
            .heading2 { configuration in
                configuration.label
                    .relativeLineSpacing(.em(0.125))
                    .markdownTextStyle {
                        FontWeight(.semibold)
                        FontSize(.em(1.5))
                    }
            }
    }
}
