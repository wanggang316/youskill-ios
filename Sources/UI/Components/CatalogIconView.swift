import SwiftUI
import SVGView

struct CatalogIconView: View {
    let icon: String?
    let fallback: String
    @State private var image: SVGView?

    var body: some View {
        Group {
            if let image {
                image
            } else {
                Image(systemName: fallback)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .frame(width: 24, height: 24)
        .accessibilityHidden(true)
        .task(id: icon) {
            image = nil
            guard let icon, !icon.isEmpty else { return }
            do {
                let data = try await CatalogIconService.shared.icon(named: icon)
                guard !Task.isCancelled else { return }
                let parsed = SVGView(data: data)
                if parsed.svg != nil { image = parsed }
            } catch {
                // Keep the local icon when the catalog icon is unavailable.
            }
        }
    }
}
