import HighlightSwift
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct CodeContentView: View {
    let content: String
    var fileExtension: String = ""

    @State private var highlightedNS: NSAttributedString?

    private static let maxHighlightCharacters = 100_000
    #if canImport(UIKit)
    private static let codeFont = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    #endif

    var body: some View {
        Group {
            #if canImport(UIKit)
            NativeCodeTextView(
                content: content,
                highlighted: highlightedNS,
                font: Self.codeFont
            )
            .background(AppTheme.cardBackground)
            #else
            Text(verbatim: content)
                .font(.system(size: 12, design: .monospaced))
            #endif
        }
        .task(id: content.hashValue) {
            await renderHighlightedContent()
        }
    }

    // MARK: - Highlight language mapping

    private var highlightLanguage: String? {
        switch fileExtension.isEmpty ? inferredFileExtension : fileExtension {
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
        case "html", "xml", "svg":
            "xml"
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

    // MARK: - Syntax highlighting

    @MainActor
    private func renderHighlightedContent() async {
        guard content.count <= Self.maxHighlightCharacters, !content.isEmpty else {
            highlightedNS = nil
            return
        }
        let highlighter = Highlight()
        do {
            let highlighted: AttributedString
            if let highlightLanguage {
                highlighted = try await highlighter.attributedText(content, language: highlightLanguage)
            } else {
                highlighted = try await highlighter.attributedText(content)
            }
            if highlighted.characters.isEmpty {
                highlightedNS = nil
            } else {
                let ns = NSMutableAttributedString(highlighted)
                #if canImport(UIKit)
                ns.addAttribute(.font, value: Self.codeFont, range: NSRange(location: 0, length: ns.length))
                #endif
                highlightedNS = ns
            }
        } catch {
            highlightedNS = nil
        }
    }
}

// MARK: - UITextView wrapper

#if canImport(UIKit)
private struct NativeCodeTextView: UIViewRepresentable {
    let content: String
    let highlighted: NSAttributedString?
    let font: UIFont

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.isEditable = false
        tv.isSelectable = true
        tv.backgroundColor = .clear
        tv.textContainerInset = UIEdgeInsets(top: 16, left: 12, bottom: 16, right: 12)
        tv.textContainer.lineFragmentPadding = 0
        // Disable line wrapping → enables horizontal scrolling
        tv.textContainer.lineBreakMode = .byClipping
        tv.textContainer.widthTracksTextView = false
        tv.textContainer.size = CGSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        tv.isDirectionalLockEnabled = true
        tv.showsHorizontalScrollIndicator = true
        tv.showsVerticalScrollIndicator = true
        tv.font = font
        tv.textColor = .label
        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        let newHash = content.hashValue
        let contentChanged = context.coordinator.contentHash != newHash

        if let highlighted {
            let savedOffset = tv.contentOffset
            tv.attributedText = highlighted
            if !contentChanged {
                tv.setContentOffset(savedOffset, animated: false)
            }
        } else {
            tv.text = content
            tv.font = font
            tv.textColor = .label
        }

        // Re-apply after content changes — attributedText assignment can reset container config.
        tv.textContainer.lineBreakMode = .byClipping
        tv.textContainer.widthTracksTextView = false
        tv.textContainer.size.width = CGFloat.greatestFiniteMagnitude

        if contentChanged {
            context.coordinator.contentHash = newHash
            tv.setContentOffset(.zero, animated: false)
        }
    }

    final class Coordinator {
        var contentHash: Int = 0
    }
}
#endif
