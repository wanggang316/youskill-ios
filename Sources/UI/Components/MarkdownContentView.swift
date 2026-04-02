import MarkdownUI
import SwiftUI

struct MarkdownContentView: View {
    let description: String?
    let markdown: String
    let baseURL: URL?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.accentSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                Markdown(markdown, baseURL: baseURL, imageBaseURL: baseURL)
                    .markdownTheme(.gitHub)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
