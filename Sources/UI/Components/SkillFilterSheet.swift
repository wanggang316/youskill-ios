import SwiftUI

struct SkillFilterSheet: View {
    @Binding var selectedSort: SkillSortOption
    let onSelect: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Capsule(style: .continuous)
                .fill(AppTheme.divider)
                .frame(width: 40, height: 5)

            VStack(spacing: 12) {
                ForEach(SkillSortOption.allCases) { option in
                    Button {
                        selectedSort = option
                        onSelect()
                    } label: {
                        SkillFilterRow(
                            title: option.title,
                            subtitle: subtitle(for: option),
                            iconName: iconName(for: option),
                            iconBackground: iconBackground(for: option),
                            isSelected: selectedSort == option
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(AppTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(AppTheme.divider, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 24, y: 14)
    }

    private func subtitle(for option: SkillSortOption) -> String {
        switch option {
        case .installCount:
            "优先查看安装量最高的热门 Skill"
        case .starCount:
            "优先查看社区 Star 数最高的 Skill"
        case .favorites:
            "只看你已经收藏的 Skill"
        }
    }

    private func iconName(for option: SkillSortOption) -> String {
        switch option {
        case .installCount:
            "arrow.up.forward"
        case .starCount:
            "star.fill"
        case .favorites:
            "heart.fill"
        }
    }

    private func iconBackground(for option: SkillSortOption) -> Color {
        switch option {
        case .installCount:
            AppTheme.accentSoft
        case .starCount:
            Color(red: 0.992, green: 0.894, blue: 0.84)
        case .favorites:
            Color(red: 0.884, green: 0.918, blue: 0.992)
        }
    }
}

private struct SkillFilterRow: View {
    let title: String
    let subtitle: String
    let iconName: String
    let iconBackground: Color
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(iconBackground)

                Image(systemName: iconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: isSelected ? "checkmark.circle.fill" : "chevron.right")
                .font(.system(size: isSelected ? 18 : 14, weight: .semibold))
                .foregroundStyle(isSelected ? AppTheme.accent : AppTheme.secondaryText)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(isSelected ? AppTheme.accentSoft : AppTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(isSelected ? AppTheme.accent.opacity(0.22) : AppTheme.divider, lineWidth: 1)
        )
    }
}
