import Foundation

struct SkillDirectoryEntry: Codable, Hashable, Identifiable {
    let path: String
    let isDirectory: Bool

    var id: String { path }
    var fileName: String { path.split(separator: "/").last.map(String.init) ?? path }
}

enum SkillFileKind: Equatable {
    case markdown
    case code
    case image
    case unsupported

    init(path: String) {
        let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
        switch ext {
        case "md", "markdown", "mdx":
            self = .markdown
        case "png", "jpg", "jpeg", "gif", "webp":
            self = .image
        case "swift", "json", "yaml", "yml", "toml", "txt", "log", "env", "ini", "js", "ts",
             "tsx", "jsx", "rs", "py", "rb", "go", "sh", "zsh", "bash", "css", "scss", "less",
             "html", "xml", "svg", "kt", "java", "sql", "lua", "dart", "c", "h", "cpp", "hpp",
             "cs", "php":
            self = .code
        default:
            self = ext.isEmpty ? .code : .unsupported
        }
    }

    var supportsTranslation: Bool {
        self == .markdown
    }
}

struct FileTreeNode: Identifiable, Hashable {
    let name: String
    let path: String
    let isDirectory: Bool
    var children: [FileTreeNode]?

    var id: String { path }
}

enum FileTreeBuilder {
    static func build(from entries: [SkillDirectoryEntry]) -> [FileTreeNode] {
        let normalized = entries.sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory {
                return lhs.isDirectory
            }
            return lhs.path.localizedCaseInsensitiveCompare(rhs.path) == .orderedAscending
        }

        var root = MutableTreeNode(name: "", path: "", isDirectory: true)
        for entry in normalized {
            root.insert(path: entry.path, isDirectory: entry.isDirectory)
        }
        return root.children.map { $0.asNode() }
    }
}

private struct MutableTreeNode {
    var name: String
    var path: String
    var isDirectory: Bool
    var children: [MutableTreeNode] = []

    mutating func insert(path: String, isDirectory: Bool) {
        let parts = path.split(separator: "/").map(String.init)
        insert(parts: parts, currentPath: "", isDirectory: isDirectory)
    }

    private mutating func insert(parts: [String], currentPath: String, isDirectory: Bool) {
        guard let head = parts.first else { return }

        let nextPath = currentPath.isEmpty ? head : "\(currentPath)/\(head)"
        let isLeaf = parts.count == 1

        if let index = children.firstIndex(where: { $0.name == head }) {
            if !isLeaf {
                children[index].insert(
                    parts: Array(parts.dropFirst()),
                    currentPath: nextPath,
                    isDirectory: isDirectory
                )
            }
            return
        }

        var child = MutableTreeNode(name: head, path: nextPath, isDirectory: !isLeaf || isDirectory)
        if !isLeaf {
            child.insert(parts: Array(parts.dropFirst()), currentPath: nextPath, isDirectory: isDirectory)
        }
        children.append(child)
        children.sort { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory {
                return lhs.isDirectory
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    func asNode() -> FileTreeNode {
        FileTreeNode(
            name: name,
            path: path,
            isDirectory: isDirectory,
            children: children.isEmpty ? nil : children.map { $0.asNode() }
        )
    }
}
