import HighlightSwift
import SwiftUI

struct CodeContentView: View {
    let content: String

    @State private var highlightedContent: AttributedString?
    private let codeFont = Font.system(size: 12, design: .monospaced)

    var body: some View {
        codeBlock
        .background(AppTheme.groupedBackground)
        .task(id: highlightKey) {
            await renderHighlightedContent()
        }
    }

    private var codeBlock: some View {
        ScrollView([.vertical, .horizontal], showsIndicators: true) {
            Group {
                if let highlightedContent {
                    Text(highlightedContent)
                } else {
                    Text(verbatim: content)
                        .foregroundStyle(.primary)
                }
            }
            .font(codeFont)
            .textSelection(.enabled)
            .fixedSize(horizontal: true, vertical: false)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
            .background(AppTheme.cardBackground)
        }
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
