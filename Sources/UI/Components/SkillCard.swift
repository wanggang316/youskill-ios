import SwiftUI

struct SkillCard: View {
    let skill: Skill
    let isFavorite: Bool
    let favoriteAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(skill.displaySubtitle)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 14) {
                        Label("\(skill.starCount)", systemImage: "star")
                    }
                    .font(.footnote)
                    .foregroundStyle(AppTheme.secondaryText)
                }

                Button(action: favoriteAction) {
                    Image(systemName: isFavorite ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isFavorite ? AppTheme.accent : AppTheme.secondaryText)
                        .frame(width: 36, height: 36)
                        .background(AppTheme.accentSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            if let description = skill.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(2)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 8)
    }
}
