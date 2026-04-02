import HighlightSwift
import SwiftUI

struct CodeContentView: View {
    let content: String

    @State private var highlightedContent: AttributedString?

    var body: some View {
        codeBlock
        .background(AppTheme.groupedBackground)
        .task(id: highlightKey) {
            await renderHighlightedContent()
        }
    }

    private var codeBlock: some View {
        ScrollView([.vertical, .horizontal], showsIndicators: true) {
            HStack(alignment: .top, spacing: 0) {
                Text(lineNumbersText)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(AppTheme.secondaryText)
                    .multilineTextAlignment(.trailing)
                    .padding(.vertical, 16)
                    .padding(.leading, 12)
                    .padding(.trailing, 10)
                    .overlay(alignment: .trailing) {
                        Rectangle()
                            .fill(AppTheme.divider)
                            .frame(width: 1)
                    }
                    .accessibilityHidden(true)

                Group {
                    if let highlightedContent {
                        Text(highlightedContent)
                    } else {
                        Text(verbatim: content)
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(.primary)
                    }
                }
                .textSelection(.enabled)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.vertical, 16)
                .padding(.leading, 12)
                .padding(.trailing, 16)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.cardBackground)
        }
    }

    private var lineCount: Int {
        max(content.split(separator: "\n", omittingEmptySubsequences: false).count, 1)
    }

    private var lineNumbersText: String {
        (1 ... lineCount).map(String.init).joined(separator: "\n")
    }

    private var highlightLanguage: String? {
        switch inferredFileExtension {
        case "js", "jsx":
            "javascript"
        case "ts", "tsx":
            "typescript"
        case "py":
            "python"
        case "rb":
            "ruby"
        case "rs":
            "rust"
        case "yml":
            "yaml"
        case "sh", "bash", "zsh", "env":
            "bash"
        case "mdx":
            "markdown"
        case "hpp":
            "cpp"
        case "h":
            "c"
        default:
            nil
        }
    }

    private var inferredFileExtension: String {
        let firstLine = content.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false).first ?? ""
        if firstLine.hasPrefix("#!/usr/bin/env ") || firstLine.hasPrefix("#!/bin/") {
            return "sh"
        }
        if firstLine.hasPrefix("{") || firstLine.hasPrefix("[") {
            return "json"
        }
        return ""
    }

    private var highlightKey: String {
        content
    }

    @MainActor
    private func renderHighlightedContent() async {
        let highlighter = Highlight()
        do {
            if let highlightLanguage {
                highlightedContent = try await highlighter.attributedText(content, language: highlightLanguage)
            } else {
                highlightedContent = try await highlighter.attributedText(content)
            }
        } catch {
            highlightedContent = nil
        }
    }
}
