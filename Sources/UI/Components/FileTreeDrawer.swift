import SwiftUI

struct FileTreeDrawer: View {
    let isPresented: Bool
    let nodes: [FileTreeNode]
    let activePath: String?
    let onClose: () -> Void
    let onSelect: (String) -> Void

    var body: some View {
        ZStack(alignment: .trailing) {
            if isPresented {
                Color.black.opacity(0.18)
                    .ignoresSafeArea()
                    .onTapGesture(perform: onClose)

                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("目录")
                            .font(.headline)
                        Spacer()
                        Button(action: onClose) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                                .padding(10)
                                .background(Color.white.opacity(0.001))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)

                    Divider()

                    if nodes.isEmpty {
                        EmptyStateView(
                            systemImage: "doc.on.doc",
                            title: "暂无文件",
                            message: "当前 Skill 没有可展示的文件。"
                        )
                    } else {
                        List {
                            OutlineGroup(nodes, children: \.children) { node in
                                if node.isDirectory {
                                    Label(node.name, systemImage: "folder")
                                        .foregroundStyle(.primary)
                                } else {
                                    Button(action: { onSelect(node.path) }) {
                                        HStack {
                                            Label(node.name, systemImage: iconName(for: node.path))
                                            Spacer()
                                        }
                                        .foregroundStyle(node.path == activePath ? AppTheme.accent : .primary)
                                        .font(node.path == activePath ? .body.weight(.semibold) : .body)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .listStyle(.plain)
                    }
                }
                .frame(width: 300)
                .frame(maxHeight: .infinity)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .padding(.vertical, 12)
                .padding(.trailing, 8)
                .transition(.move(edge: .trailing))
            }
        }
        .animation(.easeInOut(duration: 0.24), value: isPresented)
    }

    private func iconName(for path: String) -> String {
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
}
