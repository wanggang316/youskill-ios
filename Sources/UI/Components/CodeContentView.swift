import HighlightSwift
import SwiftUI
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

struct CodeContentView: View {
    let path: String
    let content: String

    @State private var highlightedContent: AttributedString?
    @State private var isCopied = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                codeBlock
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(AppTheme.groupedBackground)
        .task(id: highlightKey) {
            await renderHighlightedContent()
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(fileName)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text("\(languageLabel) · \(lineCount) 行")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.secondaryText)
            }

            Spacer(minLength: 12)

            Button {
                copyContent()
            } label: {
                Label(isCopied ? "已复制" : "复制", systemImage: isCopied ? "checkmark" : "doc.on.doc")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(isCopied ? Color.green : AppTheme.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(AppTheme.divider, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private var codeBlock: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            HStack(alignment: .top, spacing: 0) {
                Text(lineNumbersText)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(AppTheme.secondaryText)
                    .multilineTextAlignment(.trailing)
                    .padding(.vertical, 16)
                    .padding(.leading, 16)
                    .padding(.trailing, 12)
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
                .padding(.horizontal, 16)
            }
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(AppTheme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(AppTheme.divider, lineWidth: 1)
            )
        }
    }

    private var fileName: String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    private var fileExtension: String {
        URL(fileURLWithPath: path).pathExtension.lowercased()
    }

    private var lineCount: Int {
        max(content.split(separator: "\n", omittingEmptySubsequences: false).count, 1)
    }

    private var lineNumbersText: String {
        (1 ... lineCount).map(String.init).joined(separator: "\n")
    }

    private var highlightLanguage: String? {
        switch fileExtension {
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
            fileExtension.isEmpty ? nil : fileExtension
        }
    }

    private var languageLabel: String {
        switch highlightLanguage {
        case "bash":
            "Shell"
        case "cpp":
            "C++"
        case "cs":
            "C#"
        case "css":
            "CSS"
        case "dart":
            "Dart"
        case "go":
            "Go"
        case "html":
            "HTML"
        case "java":
            "Java"
        case "javascript":
            "JavaScript"
        case "json":
            "JSON"
        case "kotlin", "kt":
            "Kotlin"
        case "lua":
            "Lua"
        case "markdown":
            "Markdown"
        case "php":
            "PHP"
        case "python":
            "Python"
        case "ruby":
            "Ruby"
        case "rust":
            "Rust"
        case "sql":
            "SQL"
        case "swift":
            "Swift"
        case "toml":
            "TOML"
        case "typescript":
            "TypeScript"
        case "xml":
            "XML"
        case "yaml":
            "YAML"
        case let language?:
            language
                .split(separator: "-")
                .map { $0.capitalized }
                .joined(separator: " ")
        default:
            "Text"
        }
    }

    private var highlightKey: String {
        "\(path)|\(content)"
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

    @MainActor
    private func copyContent() {
        #if canImport(UIKit)
        UIPasteboard.general.string = content
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
        #endif

        isCopied = true

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            isCopied = false
        }
    }
}
