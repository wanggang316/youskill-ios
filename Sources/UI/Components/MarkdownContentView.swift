import SwiftUI

struct MarkdownContentView: View {
    let markdown: String

    var body: some View {
        ScrollView {
            Group {
                if let attributed = try? AttributedString(
                    markdown: markdown,
                    options: AttributedString.MarkdownParsingOptions(
                        interpretedSyntax: .full,
                        failurePolicy: .returnPartiallyParsedIfPossible
                    )
                ) {
                    Text(attributed)
                } else {
                    Text(markdown)
                }
            }
            .font(.body)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
            .textSelection(.enabled)
        }
        .background(AppTheme.cardBackground)
    }
}
