import SwiftUI

struct CodeContentView: View {
    let content: String

    var body: some View {
        ScrollView([.vertical, .horizontal]) {
            Text(content)
                .font(.system(.footnote, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .textSelection(.enabled)
        }
        .background(AppTheme.cardBackground)
    }
}
