import SwiftUI

struct FootballPrimaryButton: View {
    let title: String
    var action: () -> Void

    var body: some View {
        FootballActionButton(
            title: title,
            background: FootballColors.accent,
            borderColor: nil,
            action: action
        )
    }
}

struct FootballSecondaryButton: View {
    let title: String
    var action: () -> Void

    var body: some View {
        FootballActionButton(
            title: title,
            background: FootballColors.surfaceSecondary,
            borderColor: FootballColors.divider,
            action: action
        )
    }
}

private struct FootballActionButton: View {
    let title: String
    let background: Color
    let borderColor: Color?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(FootballTypography.body.weight(.semibold))
                .foregroundStyle(FootballColors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, FootballSpacing.md)
                .background(background)
                .clipShape(RoundedRectangle(cornerRadius: FootballRadius.standard, style: .continuous))
                .overlay {
                    if let borderColor {
                        RoundedRectangle(cornerRadius: FootballRadius.standard, style: .continuous)
                            .stroke(borderColor, lineWidth: 1)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool

    var body: some View {
        Text(title)
            .font(FootballTypography.caption)
            .foregroundStyle(isSelected ? FootballColors.textPrimary : FootballColors.textSecondary)
            .padding(.horizontal, FootballSpacing.md)
            .padding(.vertical, FootballSpacing.sm)
            .background(isSelected ? FootballColors.accent.opacity(0.25) : FootballColors.surfaceSecondary)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(isSelected ? FootballColors.accent : FootballColors.divider, lineWidth: 1))
    }
}

struct ScorePill: View {
    let status: String
    let homeScore: Int?
    let awayScore: Int?

    var body: some View {
        HStack(spacing: FootballSpacing.sm) {
            Text("\(homeScore ?? 0)")
            Text("-")
            Text("\(awayScore ?? 0)")
            Divider()
                .frame(height: 10)
            Text(status)
                .foregroundStyle(FootballColors.accent)
        }
        .font(FootballTypography.caption)
        .foregroundStyle(FootballColors.textPrimary)
        .padding(.horizontal, FootballSpacing.md)
        .padding(.vertical, FootballSpacing.sm)
        .background(FootballColors.surfaceSecondary)
        .clipShape(Capsule())
    }
}

struct FormBadge: View {
    let results: [FormResult]

    var body: some View {
        HStack(spacing: FootballSpacing.xs) {
            ForEach(Array(results.enumerated()), id: \.offset) { _, result in
                Text(result.rawValue)
                    .font(FootballTypography.tiny)
                    .foregroundStyle(FootballColors.textPrimary)
                    .frame(width: 20, height: 20)
                    .background(background(for: result))
                    .clipShape(Circle())
            }
        }
    }

    private func background(for result: FormResult) -> Color {
        switch result {
        case .win:
            return FootballColors.accent
        case .draw:
            return FootballColors.warning
        case .loss:
            return FootballColors.danger
        }
    }
}

struct LoadingPitchView: View {
    var body: some View {
        VStack(spacing: FootballSpacing.lg) {
            Image(systemName: "soccerball.inverse")
                .font(.system(size: 42))
                .foregroundStyle(FootballColors.accent)
            Text("Loading football intelligence")
                .font(FootballTypography.cardTitle)
                .foregroundStyle(FootballColors.textPrimary)
            ProgressView()
                .tint(FootballColors.accent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FootballColors.background.ignoresSafeArea())
    }
}

struct EmptyStateCard: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        VStack(spacing: FootballSpacing.md) {
            Image(systemName: systemImage)
                .font(.system(size: 36))
                .foregroundStyle(FootballColors.accent)
            Text(title)
                .font(FootballTypography.cardTitle)
                .foregroundStyle(FootballColors.textPrimary)
            Text(message)
                .font(FootballTypography.body)
                .foregroundStyle(FootballColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .footballCardStyle()
    }
}

struct ErrorRetryCard: View {
    let title: String
    let message: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: FootballSpacing.md) {
            Text(title)
                .font(FootballTypography.cardTitle)
                .foregroundStyle(FootballColors.textPrimary)
            Text(message)
                .font(FootballTypography.body)
                .foregroundStyle(FootballColors.textSecondary)
            FootballSecondaryButton(title: "Retry", action: action)
        }
        .footballCardStyle()
    }
}

struct CustomNavigationHeader: View {
    let title: String
    let subtitle: String
    var trailing: AnyView? = nil

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: FootballSpacing.xs) {
                    Text(title)
                        .font(FootballTypography.hero)
                        .foregroundStyle(Color.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(subtitle)
                        .font(FootballTypography.body)
                        .foregroundStyle(Color.white.opacity(0.9))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
                trailing
                    .foregroundStyle(Color.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, FootballSpacing.lg)
            .padding(.top, FootballSpacing.md)
            .padding(.bottom, FootballSpacing.md)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FootballColors.accent)
        .background(FootballColors.accent.ignoresSafeArea(edges: .top))
    }
}

struct BottomSheetFilter<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: FootballSpacing.lg) {
            Text(title)
                .font(FootballTypography.section)
                .foregroundStyle(FootballColors.textPrimary)
            content
        }
        .padding(FootballSpacing.lg)
        .background(FootballColors.surfacePrimary)
    }
}

struct RemoteBadgeImage: View {
    let urlString: String?
    let placeholderText: String
    var dimension: CGFloat = 36

    private var cornerRadius: CGFloat {
        min(14, dimension * 0.32)
    }

    var body: some View {
        Group {
            if let urlString, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFit()
                    default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: dimension, height: dimension)
        .background(FootballColors.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private var placeholder: some View {
        Text(String(placeholderText.prefix(2)).uppercased())
            .font(FootballTypography.caption)
            .foregroundStyle(FootballColors.textPrimary)
    }
}

struct LeagueCard: View {
    let league: League

    var body: some View {
        HStack(spacing: FootballSpacing.md) {
            RemoteBadgeImage(urlString: league.logoURL, placeholderText: league.name)
            VStack(alignment: .leading, spacing: 2) {
                Text(league.name)
                    .font(FootballTypography.cardTitle)
                    .foregroundStyle(FootballColors.textPrimary)
                Text("\(league.country.name) • \(league.currentSeason.slashDisplay)")
                    .font(FootballTypography.caption)
                    .foregroundStyle(FootballColors.textSecondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .footballCardStyle()
    }
}

struct TeamCard: View {
    let team: Team
    let isFavorite: Bool

    var body: some View {
        HStack(spacing: FootballSpacing.md) {
            RemoteBadgeImage(urlString: team.logoURL, placeholderText: team.name)
            VStack(alignment: .leading, spacing: 2) {
                Text(team.name)
                    .font(FootballTypography.cardTitle)
                    .foregroundStyle(FootballColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text(team.venueName ?? team.country)
                    .font(FootballTypography.caption)
                    .foregroundStyle(FootballColors.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer()
            Image(systemName: isFavorite ? "star.fill" : "star")
                .foregroundStyle(isFavorite ? FootballColors.warning : FootballColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .footballCardStyle()
    }
}

struct MatchCard: View {
    let fixture: Fixture

    var body: some View {
        VStack(alignment: .leading, spacing: FootballSpacing.md) {
            HStack {
                Text(fixture.league.name)
                    .font(FootballTypography.caption)
                    .foregroundStyle(FootballColors.textSecondary)
                Spacer()
                ScorePill(status: fixture.statusDisplay, homeScore: fixture.score.home, awayScore: fixture.score.away)
            }
            VStack(alignment: .leading, spacing: FootballSpacing.sm) {
                teamScoreRow(team: fixture.homeTeam, score: scoreText(fixture.score.home))
                teamScoreRow(team: fixture.awayTeam, score: scoreText(fixture.score.away))
            }
            Text("\(fixture.venue ?? "Venue TBC") • \(DateFormatters.matchDate.string(from: fixture.date))")
                .font(FootballTypography.caption)
                .foregroundStyle(FootballColors.textSecondary)
        }
        .footballCardStyle()
    }

    private func teamScoreRow(team: Team, score: String) -> some View {
        HStack(spacing: FootballSpacing.sm) {
            RemoteBadgeImage(urlString: team.logoURL, placeholderText: team.name, dimension: 34)
            Text(team.name)
                .font(FootballTypography.cardTitle)
                .foregroundStyle(FootballColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(score)
                .font(FootballTypography.cardTitle)
                .foregroundStyle(FootballColors.textPrimary)
                .frame(minWidth: 28, alignment: .trailing)
        }
    }

    private func scoreText(_ score: Int?) -> String {
        score.map(String.init) ?? "-"
    }
}

struct LiveScoreCard: View {
    let fixture: Fixture

    var body: some View {
        VStack(alignment: .leading, spacing: FootballSpacing.md) {
            HStack {
                Label("Live", systemImage: "dot.radiowaves.left.and.right")
                    .font(FootballTypography.caption)
                    .foregroundStyle(FootballColors.accent)
                Spacer()
                Text(fixture.statusDisplay)
                    .font(FootballTypography.caption)
                    .foregroundStyle(FootballColors.textPrimary)
            }
            VStack(alignment: .leading, spacing: FootballSpacing.sm) {
                liveTeamRow(team: fixture.homeTeam, score: fixture.score.home ?? 0)
                liveTeamRow(team: fixture.awayTeam, score: fixture.score.away ?? 0)
            }
        }
        .padding(FootballSpacing.lg)
        .background(FootballColors.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: FootballRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FootballRadius.card, style: .continuous)
                .stroke(FootballColors.accent.opacity(0.6), lineWidth: 1)
        )
    }

    private func liveTeamRow(team: Team, score: Int) -> some View {
        matchTeamRow(team: team, scoreText: "\(score)", scoreFont: FootballTypography.title, minScoreWidth: 32)
    }

    private func matchTeamRow(team: Team, scoreText: String, scoreFont: Font, minScoreWidth: CGFloat) -> some View {
        HStack(spacing: FootballSpacing.sm) {
            RemoteBadgeImage(urlString: team.logoURL, placeholderText: team.name, dimension: 34)
            Text(team.name)
                .font(FootballTypography.cardTitle)
                .foregroundStyle(FootballColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(scoreText)
                .font(scoreFont)
                .foregroundStyle(FootballColors.textPrimary)
                .frame(minWidth: minScoreWidth, alignment: .trailing)
        }
    }
}

struct StandingRowView: View {
    let row: StandingRow

    var body: some View {
        HStack(spacing: FootballSpacing.sm) {
            Text("\(row.rank)")
                .frame(width: 22, alignment: .leading)
            RemoteBadgeImage(urlString: row.team.logoURL, placeholderText: row.team.name, dimension: 28)
            Text(row.team.name)
                .lineLimit(1)
            Spacer()
            rowValue(row.played)
            rowValue(row.won)
            rowValue(row.drawn)
            rowValue(row.lost)
            rowValue(row.goalsFor)
            rowValue(row.goalsAgainst)
            rowValue(row.goalDifference)
            Text("\(row.points)")
                .frame(width: 32, alignment: .trailing)
                .foregroundStyle(FootballColors.accent)
            FormBadge(results: row.form)
        }
        .font(FootballTypography.caption)
        .foregroundStyle(FootballColors.textPrimary)
        .padding(.vertical, FootballSpacing.sm)
    }

    private func rowValue(_ value: Int) -> some View {
        Text("\(value)")
            .frame(width: 24, alignment: .trailing)
    }
}

struct StatComparisonBar: View {
    let title: String
    let leftValue: Double
    let rightValue: Double
    let suffix: String

    var body: some View {
        VStack(alignment: .leading, spacing: FootballSpacing.sm) {
            HStack {
                Text("\(formatted(leftValue))\(suffix)")
                Spacer()
                Text(title)
                    .foregroundStyle(FootballColors.textSecondary)
                Spacer()
                Text("\(formatted(rightValue))\(suffix)")
            }
            .font(FootballTypography.caption)
            .foregroundStyle(FootballColors.textPrimary)

            GeometryReader { geometry in
                let total = max(leftValue + rightValue, 1)
                HStack(spacing: 0) {
                    FootballColors.accent
                        .frame(width: geometry.size.width * (leftValue / total))
                    FootballColors.surfaceTertiary
                        .frame(width: geometry.size.width * (rightValue / total))
                }
                .clipShape(Capsule())
            }
            .frame(height: 8)
        }
    }

    private func formatted(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(format: "%.1f", value)
    }
}

struct CustomTabBar: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        HStack {
            ForEach(AppTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: tab.systemImage)
                        Text(tab.title)
                            .font(FootballTypography.tiny)
                    }
                    .foregroundStyle(selectedTab == tab ? FootballColors.accent : FootballColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, FootballSpacing.sm)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, FootballSpacing.md)
        .padding(.top, FootballSpacing.sm)
        .padding(.bottom, FootballSpacing.md)
        .background(FootballColors.surfacePrimary)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(FootballColors.divider)
                .frame(height: 1)
        }
    }
}
