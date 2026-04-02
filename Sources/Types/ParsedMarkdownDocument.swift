import Foundation

struct ParsedMarkdownDocument: Equatable, Sendable {
    let frontmatterDescription: String?
    let body: String
    let hasFrontmatter: Bool

    static let empty = ParsedMarkdownDocument(
        frontmatterDescription: nil,
        body: "",
        hasFrontmatter: false
    )
}

enum MarkdownFrontmatterParser {
    static func parse(_ content: String?) -> ParsedMarkdownDocument {
        guard var content, !content.isEmpty else {
            return .empty
        }

        if content.hasPrefix("\u{FEFF}") {
            content.removeFirst()
        }

        let normalized = content.replacingOccurrences(of: "\r\n", with: "\n")
        guard normalized.hasPrefix("---\n") else {
            return ParsedMarkdownDocument(
                frontmatterDescription: nil,
                body: normalized.trimmingCharacters(in: .whitespacesAndNewlines),
                hasFrontmatter: false
            )
        }

        let lines = normalized.components(separatedBy: "\n")
        guard let closingIndex = lines.dropFirst().firstIndex(of: "---") else {
            return ParsedMarkdownDocument(
                frontmatterDescription: nil,
                body: normalized.trimmingCharacters(in: .whitespacesAndNewlines),
                hasFrontmatter: false
            )
        }

        let frontmatterLines = Array(lines[1 ..< closingIndex])
        let body = lines.dropFirst(closingIndex + 1).joined(separator: "\n")

        return ParsedMarkdownDocument(
            frontmatterDescription: extractDescription(from: frontmatterLines),
            body: body.trimmingCharacters(in: .whitespacesAndNewlines),
            hasFrontmatter: true
        )
    }

    private static func extractDescription(from lines: [String]) -> String? {
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("description:") else { continue }

            let value = String(trimmed.dropFirst("description:".count))
                .trimmingCharacters(in: .whitespaces)

            if value.isEmpty {
                return nil
            }

            if ["|", "|-", ">", ">-"].contains(value) {
                let blockLines = collectIndentedBlock(from: Array(lines.dropFirst(index + 1)))
                guard !blockLines.isEmpty else { return nil }

                if value.hasPrefix(">") {
                    return blockLines
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .joined(separator: " ")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }

                return blockLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            }

            return unquote(value)
        }

        return nil
    }

    private static func collectIndentedBlock(from lines: [String]) -> [String] {
        var block: [String] = []

        for line in lines {
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                if !block.isEmpty {
                    block.append("")
                }
                continue
            }

            guard line.first?.isWhitespace == true else {
                break
            }

            block.append(line.trimmingCharacters(in: .whitespaces))
        }

        while block.last?.isEmpty == true {
            block.removeLast()
        }

        return block
    }

    private static func unquote(_ value: String) -> String {
        guard value.count >= 2 else { return value }
        if (value.hasPrefix("\"") && value.hasSuffix("\"")) || (value.hasPrefix("'") && value.hasSuffix("'")) {
            return String(value.dropFirst().dropLast())
        }
        return value
    }
}
