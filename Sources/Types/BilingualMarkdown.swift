import Foundation

enum MarkdownBlockKind: Equatable, Sendable {
    case heading(level: Int, text: String)
    case paragraph
    case list
    case blockquote
    case table
    case code
    case thematicBreak
    case html

    /// Code, rules, and raw HTML are not translated, so bilingual view shows them once.
    var isTranslatable: Bool {
        switch self {
        case .code, .thematicBreak, .html:
            false
        default:
            true
        }
    }

    fileprivate var category: Int {
        switch self {
        case .heading: 0
        case .paragraph: 1
        case .list: 2
        case .blockquote: 3
        case .table: 4
        case .code: 5
        case .thematicBreak: 6
        case .html: 7
        }
    }
}

struct MarkdownBlock: Equatable, Sendable {
    let kind: MarkdownBlockKind
    let source: String
}

/// One stacked unit of the bilingual reader.
enum BilingualSegment: Equatable, Sendable {
    /// A block shown once: untranslated kinds, identical text, or an original block without a counterpart.
    case original(String)
    /// A translated block without an original counterpart.
    case translated(String)
    /// Whole original block followed by the whole translated block (paragraphs, tables, quotes, unmatched lists).
    case stacked(original: String, translated: String)
    /// The translated heading is shown as a second line of the same heading.
    case heading(level: Int, original: String, translated: String)
    /// A list with each item's translation inserted after the item.
    case list(String)
}

enum MarkdownBlockParser {
    static func blocks(in markdown: String) -> [MarkdownBlock] {
        let lines = markdown
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")
        var blocks: [MarkdownBlock] = []
        var index = 0

        while index < lines.count {
            let line = lines[index]
            if line.isBlank {
                index += 1
                continue
            }

            let start = index
            let kind: MarkdownBlockKind

            if let fence = fenceMarker(line) {
                index += 1
                while index < lines.count, !closesFence(lines[index], fence: fence) {
                    index += 1
                }
                index = min(index + 1, lines.count)
                kind = .code
            } else if let heading = atxHeading(line) {
                index += 1
                kind = .heading(level: heading.level, text: heading.text)
            } else if isThematicBreak(line) {
                index += 1
                kind = .thematicBreak
            } else if isHTMLStart(line) {
                index = endOfParagraphLike(lines, from: index)
                kind = .html
            } else if index + 1 < lines.count, line.contains("|"), isTableSeparator(lines[index + 1]) {
                index += 2
                while index < lines.count, !lines[index].isBlank, lines[index].contains("|") {
                    index += 1
                }
                kind = .table
            } else if isBlockquoteStart(line) {
                index = endOfParagraphLike(lines, from: index)
                kind = .blockquote
            } else if listMarker(line) != nil {
                index = endOfList(lines, from: index)
                kind = .list
            } else {
                var end = index + 1
                var setextLevel: Int?
                while end < lines.count, !lines[end].isBlank, !interruptsParagraph(lines[end]), listMarker(lines[end]) == nil {
                    if lines[end].contains("|"), end + 1 < lines.count, isTableSeparator(lines[end + 1]) {
                        break
                    }
                    if let level = setextUnderlineLevel(lines[end]) {
                        setextLevel = level
                        end += 1
                        break
                    }
                    end += 1
                }
                if let setextLevel {
                    let text = lines[index ..< end - 1]
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .joined(separator: " ")
                    kind = .heading(level: setextLevel, text: text)
                } else {
                    kind = .paragraph
                }
                index = end
            }

            let source = lines[start ..< index].joined(separator: "\n").trimmingTrailingWhitespaceLines()
            blocks.append(MarkdownBlock(kind: kind, source: source))
        }

        return blocks
    }

    /// Splits a list block into its top-level items, keeping each item's source lines.
    static func listItems(in list: String) -> [String] {
        let lines = list.components(separatedBy: "\n")
        guard let first = lines.first, let firstMarker = listMarker(first) else { return [list] }
        var items: [[String]] = []

        for line in lines {
            if let marker = listMarker(line), marker.indent == firstMarker.indent {
                items.append([line])
            } else if items.isEmpty {
                items.append([line])
            } else {
                items[items.count - 1].append(line)
            }
        }

        return items.map { $0.joined(separator: "\n").trimmingTrailingWhitespaceLines() }
    }

    struct ListMarker {
        let indent: Int
        /// Columns from the line start to the item content.
        let contentOffset: Int
    }

    static func listMarker(_ line: String) -> ListMarker? {
        let characters = Array(line)
        var position = 0
        while position < characters.count, characters[position] == " " {
            position += 1
        }
        let indent = position
        guard indent <= 3, position < characters.count else { return nil }

        if "-*+".contains(characters[position]) {
            position += 1
        } else {
            let digitsStart = position
            while position < characters.count, characters[position].isASCII, characters[position].isNumber {
                position += 1
            }
            let digitCount = position - digitsStart
            guard (1 ... 9).contains(digitCount), position < characters.count, ".)".contains(characters[position]) else {
                return nil
            }
            position += 1
        }

        if position == characters.count {
            return ListMarker(indent: indent, contentOffset: position + 1)
        }
        guard characters[position] == " " || characters[position] == "\t" else { return nil }
        var contentStart = position
        while contentStart < characters.count, characters[contentStart] == " " {
            contentStart += 1
        }
        if contentStart - position > 4 {
            contentStart = position + 1
        }
        return ListMarker(indent: indent, contentOffset: contentStart)
    }

    private static func endOfParagraphLike(_ lines: [String], from start: Int) -> Int {
        var end = start + 1
        while end < lines.count, !lines[end].isBlank {
            end += 1
        }
        return end
    }

    private static func endOfList(_ lines: [String], from start: Int) -> Int {
        guard let firstMarker = listMarker(lines[start]) else { return start + 1 }
        var end = start + 1
        var openFence: String?

        while end < lines.count {
            let line = lines[end]
            if let fence = openFence {
                if closesFence(line, fence: fence) { openFence = nil }
                end += 1
                continue
            }
            if line.isBlank {
                // A blank line continues the list only if the next content is another item or indented content.
                var next = end + 1
                while next < lines.count, lines[next].isBlank {
                    next += 1
                }
                guard next < lines.count else { break }
                let nextLine = lines[next]
                let continuesItem = nextLine.leadingSpaces >= firstMarker.contentOffset
                let continuesList = listMarker(nextLine).map { $0.indent == firstMarker.indent } ?? false
                guard continuesItem || continuesList else { break }
                end = next
                continue
            }
            if line.leadingSpaces < firstMarker.contentOffset, listMarker(line) == nil, interruptsParagraph(line) {
                break
            }
            if let fence = fenceMarker(line) {
                openFence = fence
            }
            end += 1
        }

        return end
    }

    private static func interruptsParagraph(_ line: String) -> Bool {
        fenceMarker(line) != nil
            || atxHeading(line) != nil
            || isBlockquoteStart(line)
            || (isThematicBreak(line) && setextUnderlineLevel(line) == nil)
            || isHTMLStart(line)
    }

    fileprivate static func fenceMarker(_ line: String) -> String? {
        let trimmed = line.trimmingLeadingSpaces(upTo: 3)
        guard let first = trimmed.first, first == "`" || first == "~" else { return nil }
        let marker = String(trimmed.prefix { $0 == first })
        return marker.count >= 3 ? marker : nil
    }

    private static func closesFence(_ line: String, fence: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let first = fence.first, trimmed.first == first else { return false }
        let run = trimmed.prefix { $0 == first }
        return run.count >= fence.count && run.count == trimmed.count
    }

    fileprivate static func atxHeading(_ line: String) -> (level: Int, text: String)? {
        let trimmed = line.trimmingLeadingSpaces(upTo: 3)
        let hashes = trimmed.prefix { $0 == "#" }
        guard (1 ... 6).contains(hashes.count) else { return nil }
        let rest = trimmed.dropFirst(hashes.count)
        guard rest.isEmpty || rest.first == " " || rest.first == "\t" else { return nil }
        var text = rest.trimmingCharacters(in: .whitespaces)
        // Optional closing sequence: "## Title ##".
        if let closingStart = text.lastIndex(where: { $0 != "#" }) {
            let closing = text[text.index(after: closingStart)...]
            if !closing.isEmpty, text[closingStart] == " " {
                text = String(text[...closingStart]).trimmingCharacters(in: .whitespaces)
            }
        } else {
            text = ""
        }
        return (hashes.count, text)
    }

    private static func isThematicBreak(_ line: String) -> Bool {
        let compact = line.filter { $0 != " " && $0 != "\t" }
        guard line.leadingSpaces <= 3, compact.count >= 3, let first = compact.first, "-*_".contains(first) else {
            return false
        }
        return compact.allSatisfy { $0 == first }
    }

    private static func setextUnderlineLevel(_ line: String) -> Int? {
        guard line.leadingSpaces <= 3 else { return nil }
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let first = trimmed.first, first == "=" || first == "-", trimmed.allSatisfy({ $0 == first }) else {
            return nil
        }
        return first == "=" ? 1 : 2
    }

    private static func isHTMLStart(_ line: String) -> Bool {
        let trimmed = line.trimmingLeadingSpaces(upTo: 3)
        guard trimmed.first == "<", let next = trimmed.dropFirst().first else { return false }
        return next.isLetter || next == "!" || next == "/"
    }

    private static func isBlockquoteStart(_ line: String) -> Bool {
        line.trimmingLeadingSpaces(upTo: 3).first == ">"
    }

    private static func isTableSeparator(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.contains("-") else { return false }
        let cells = trimmed
            .trimmingCharacters(in: CharacterSet(charactersIn: "|"))
            .components(separatedBy: "|")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard trimmed.contains("|") || cells.count > 1 else { return false }
        return cells.allSatisfy { cell in
            !cell.isEmpty && cell.allSatisfy { $0 == "-" || $0 == ":" } && cell.contains("-")
        }
    }
}

enum BilingualMarkdownAligner {
    static func segments(original: String, translated: String) -> [BilingualSegment] {
        let originalBlocks = MarkdownBlockParser.blocks(in: original)
        let translatedBlocks = MarkdownBlockParser.blocks(in: translated)
        var segments: [BilingualSegment] = []

        for step in align(originalBlocks, translatedBlocks) {
            switch step {
            case let .matched(source, translation):
                segments.append(segment(original: source, translated: translation))
            case let .originalOnly(block):
                segments.append(.original(block.source))
            case let .translatedOnly(block):
                // Untranslated kinds are already shown from the original side.
                if block.kind.isTranslatable {
                    segments.append(.translated(block.source))
                }
            }
        }

        return segments
    }

    private static func segment(original: MarkdownBlock, translated: MarkdownBlock) -> BilingualSegment {
        if !original.kind.isTranslatable || original.source.normalizedForComparison == translated.source.normalizedForComparison {
            return .original(original.source)
        }

        switch (original.kind, translated.kind) {
        case let (.heading(level, originalText), .heading(_, translatedText)):
            return .heading(level: level, original: originalText, translated: translatedText)
        case (.list, .list):
            let originalItems = MarkdownBlockParser.listItems(in: original.source)
            let translatedItems = MarkdownBlockParser.listItems(in: translated.source)
            guard originalItems.count == translatedItems.count else {
                return .stacked(original: original.source, translated: translated.source)
            }
            let merged = zip(originalItems, translatedItems).map(mergeListItem)
            return .list(merged.joined(separator: "\n"))
        default:
            return .stacked(original: original.source, translated: translated.source)
        }
    }

    /// Appends the translated item content as an indented paragraph inside the original item.
    private static func mergeListItem(original: String, translated: String) -> String {
        if original.normalizedForComparison == translated.normalizedForComparison {
            return original + "\n"
        }
        let originalLines = original.components(separatedBy: "\n")
        let translatedLines = translated.components(separatedBy: "\n")
        guard let originalMarker = MarkdownBlockParser.listMarker(originalLines[0]),
              let translatedMarker = MarkdownBlockParser.listMarker(translatedLines[0]) else {
            return original + "\n\n" + translated
        }

        let indent = String(repeating: " ", count: originalMarker.contentOffset)
        var body = [String(translatedLines[0].dropFirst(min(translatedMarker.contentOffset, translatedLines[0].count)))]
        body += translatedLines.dropFirst().map { line in
            String(line.dropFirst(min(line.leadingSpaces, translatedMarker.contentOffset)))
        }
        let indented = body.map { $0.isBlank ? "" : indent + $0 }
        return ([original, ""] + indented).joined(separator: "\n") + "\n"
    }

    private enum Step {
        case matched(MarkdownBlock, MarkdownBlock)
        case originalOnly(MarkdownBlock)
        case translatedOnly(MarkdownBlock)
    }

    /// Longest common subsequence over block kinds, as on desktop.
    private static func align(_ original: [MarkdownBlock], _ translated: [MarkdownBlock]) -> [Step] {
        let rows = original.count
        let columns = translated.count
        var lengths = Array(repeating: Array(repeating: 0, count: columns + 1), count: rows + 1)

        for row in stride(from: rows - 1, through: 0, by: -1) {
            for column in stride(from: columns - 1, through: 0, by: -1) {
                if original[row].kind.category == translated[column].kind.category {
                    lengths[row][column] = lengths[row + 1][column + 1] + 1
                } else {
                    lengths[row][column] = max(lengths[row + 1][column], lengths[row][column + 1])
                }
            }
        }

        var steps: [Step] = []
        var row = 0
        var column = 0
        while row < rows, column < columns {
            if original[row].kind.category == translated[column].kind.category {
                steps.append(.matched(original[row], translated[column]))
                row += 1
                column += 1
            } else if lengths[row + 1][column] >= lengths[row][column + 1] {
                steps.append(.originalOnly(original[row]))
                row += 1
            } else {
                steps.append(.translatedOnly(translated[column]))
                column += 1
            }
        }
        steps += original[row...].map(Step.originalOnly)
        steps += translated[column...].map(Step.translatedOnly)
        return steps
    }
}

private extension String {
    var isBlank: Bool {
        allSatisfy(\.isWhitespace)
    }

    var leadingSpaces: Int {
        prefix { $0 == " " }.count
    }

    var normalizedForComparison: String {
        components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
    }

    func trimmingLeadingSpaces(upTo limit: Int) -> Substring {
        let count = min(leadingSpaces, limit)
        return dropFirst(count)
    }

    func trimmingTrailingWhitespaceLines() -> String {
        var lines = components(separatedBy: "\n")
        while let last = lines.last, last.isBlank {
            lines.removeLast()
        }
        return lines.joined(separator: "\n")
    }
}
