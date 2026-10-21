import SwiftUI

struct FileTreeDrawer: View {
    @Binding var isPresented: Bool
    let nodes: [FileTreeNode]
    let activePath: String?
    let onSelect: (String) -> Void

    @State private var expandedDirectories: Set<String> = []

    private let drawerAnimation = Animation.interactiveSpring(
        response: 0.32,
        dampingFraction: 0.86,
        blendDuration: 0.12
    )

    var body: some View {
        GeometryReader { geometry in
            let drawerWidth = min(geometry.size.width, min(max(geometry.size.width * 0.82, 294), 336))

            ZStack(alignment: .trailing) {
                if isPresented {
                    Color.black.opacity(0.24)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .onTapGesture(perform: closeDrawer)

                    drawerPanel(width: drawerWidth)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            .animation(drawerAnimation, value: isPresented)
        }
        .onAppear {
            syncExpandedDirectories(reset: true)
        }
        .onChange(of: nodes) { _, _ in
            syncExpandedDirectories(reset: true)
        }
        .onChange(of: activePath) { _, _ in
            revealActivePath()
        }
    }

    private func drawerPanel(width: CGFloat) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.string("detail.directory"))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)

                    if let activePath, !activePath.isEmpty {
                        Text(activePath)
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryText)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                Spacer()

                Button(action: closeDrawer) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(width: 34, height: 34)
                        .background(AppTheme.groupedBackground)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.string("common.done"))
                .accessibilityIdentifier("detail.files.close")
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 14)

            Divider()

            if nodes.isEmpty {
                EmptyStateView(
                    systemImage: "doc.on.doc",
                    title: L10n.string("detail.no_files_title"),
                    message: L10n.string("detail.no_files_message")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    FileTreeList(
                        nodes: nodes,
                        activePath: activePath,
                        expandedDirectories: $expandedDirectories,
                        onSelect: selectFile
                    )
                    .padding(.horizontal, 14)
                    .padding(.vertical, 16)
                }
            }
        }
        .frame(width: width, alignment: .top)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(AppTheme.divider, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 22, x: -6, y: 0)
        .padding(.top, 10)
        .padding(.bottom, 0)
        .padding(.trailing, 0)
        .ignoresSafeArea(edges: .bottom)
    }

    private func selectFile(_ path: String) {
        closeDrawer()
        Task {
            try? await Task.sleep(for: .milliseconds(180))
            onSelect(path)
        }
    }

    private func closeDrawer() {
        withAnimation(drawerAnimation) {
            isPresented = false
        }
    }

    private func syncExpandedDirectories(reset: Bool) {
        let directoryPaths = Set(directoryPaths(in: nodes))

        if reset || expandedDirectories.isEmpty {
            expandedDirectories = directoryPaths
        } else {
            expandedDirectories = expandedDirectories.intersection(directoryPaths)
        }

        revealActivePath()
    }

    private func revealActivePath() {
        expandedDirectories.formUnion(ancestorPaths(for: activePath))
    }

    private func ancestorPaths(for path: String?) -> [String] {
        guard let path else { return [] }
        let parts = path.split(separator: "/")
        guard parts.count > 1 else { return [] }

        var prefixes: [String] = []
        for index in 1..<parts.count {
            prefixes.append(parts[0..<index].joined(separator: "/"))
        }
        return prefixes
    }

    private func directoryPaths(in nodes: [FileTreeNode]) -> [String] {
        nodes.flatMap { node in
            if node.isDirectory {
                return [node.path] + directoryPaths(in: node.children ?? [])
            }
            return []
        }
    }
}

private struct FileTreeList: View {
    let nodes: [FileTreeNode]
    let activePath: String?
    @Binding var expandedDirectories: Set<String>
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(nodes) { node in
                FileTreeNodeView(
                    node: node,
                    depth: 0,
                    activePath: activePath,
                    expandedDirectories: $expandedDirectories,
                    onSelect: onSelect
                )
            }
        }
    }
}

private struct FileTreeNodeView: View {
    let node: FileTreeNode
    let depth: Int
    let activePath: String?
    @Binding var expandedDirectories: Set<String>
    let onSelect: (String) -> Void

    var body: some View {
        Group {
            if node.isDirectory {
                directoryRow
            } else {
                fileRow
            }
        }
    }

    private var directoryRow: some View {
        let isExpanded = expandedDirectories.contains(node.path)
        let isActiveBranch = activePath?.hasPrefix("\(node.path)/") == true

        return VStack(alignment: .leading, spacing: 4) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isExpanded {
                        expandedDirectories.remove(node.path)
                    } else {
                        expandedDirectories.insert(node.path)
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppTheme.secondaryText)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))

                    Image(systemName: isExpanded ? "folder.fill" : "folder")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)

                    Text(node.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer(minLength: 0)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(isActiveBranch ? AppTheme.accentSoft.opacity(0.48) : Color.clear)
                )
            }
            .buttonStyle(.plain)

            if isExpanded, let children = node.children, !children.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(children) { child in
                        FileTreeNodeView(
                            node: child,
                            depth: depth + 1,
                            activePath: activePath,
                            expandedDirectories: $expandedDirectories,
                            onSelect: onSelect
                        )
                    }
                }
                .padding(.leading, 16)
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1, style: .continuous)
                        .fill(AppTheme.divider)
                        .frame(width: 1)
                        .padding(.vertical, 5)
                }
            }
        }
        .padding(.leading, CGFloat(depth) * 3)
    }

    private var fileRow: some View {
        let isSelected = node.path == activePath
        let foregroundStyle = isSelected ? AppTheme.accent : Color.primary

        return Button {
            onSelect(node.path)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: fileIconName(for: node.path))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isSelected ? AppTheme.accent : AppTheme.secondaryText)

                Text(node.name)
                    .font(.subheadline.weight(isSelected ? .semibold : .medium))
                    .foregroundStyle(foregroundStyle)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer(minLength: 0)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? AppTheme.accentSoft : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .padding(.leading, CGFloat(depth) * 3)
        .accessibilityIdentifier("detail.file.\(node.path)")
    }
}

private func fileIconName(for path: String) -> String {
    switch SkillFileKind(path: path) {
    case .markdown:
        "doc.text"
    case .code:
        "chevron.left.forwardslash.chevron.right"
    case .image:
        "photo"
    case .unsupported:
        "doc"
    }
}
