import SwiftUI

struct SearchScreen: View {
    @ObservedObject var router: AppRouter
    @ObservedObject var viewModel: LaunchViewModel
    @State private var query = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: FootballSpacing.md) {
                CustomNavigationHeader(title: "Search", subtitle: "Find leagues, teams, and fixtures across your football context.")
                ScrollView {
                    VStack(alignment: .leading, spacing: FootballSpacing.lg) {
                        TextField("Search clubs, leagues, or fixtures", text: $query)
                            .textFieldStyle(.plain)
                            .padding(FootballSpacing.lg)
                            .background(FootballColors.surfacePrimary)
                            .clipShape(RoundedRectangle(cornerRadius: FootballRadius.card, style: .continuous))
                            .foregroundStyle(FootballColors.textPrimary)
                            .submitLabel(.search)
                            .onSubmit {
                                Task { await viewModel.search(query, selection: router.selection) }
                            }

                        switch viewModel.searchState {
                        case .idle:
                            EmptyStateCard(title: "Search the Football Graph", message: "Try a team, league, or club matchup to start exploring.", systemImage: "magnifyingglass")
                        case .loading:
                            LoadingPitchView().frame(height: 220)
                        case .empty(let message):
                            EmptyStateCard(title: "No Search Results", message: message, systemImage: "magnifyingglass.circle")
                        case .failure(let message):
                            ErrorRetryCard(title: "Search Failed", message: message) {
                                Task { await viewModel.search(query, selection: router.selection) }
                            }
                        case .success(let results, _):
                            resultBlock(title: "Leagues") {
                                ForEach(results.leagues) { league in
                                    LeagueCard(league: league)
                                }
                            }
                            resultBlock(title: "Teams") {
                                ForEach(results.teams) { team in
                                    TeamCard(team: team, isFavorite: viewModel.favorites.contains(where: { $0.team.id == team.id }))
                                }
                            }
                            resultBlock(title: "Fixtures") {
                                ForEach(results.fixtures) { fixture in
                                    MatchCard(fixture: fixture)
                                }
                            }
                        }
                    }
                    .padding(FootballSpacing.lg)
                }
            }
            .background(FootballColors.background)
        }
    }

    private func resultBlock<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: FootballSpacing.md) {
            Text(title)
                .font(FootballTypography.section)
                .foregroundStyle(FootballColors.textPrimary)
            content()
        }
    }
}

struct SettingsScreen: View {
    @ObservedObject var router: AppRouter
    @ObservedObject var viewModel: LaunchViewModel
    @State private var refreshInterval: Double = 20
    @State private var clearCacheResult = ""
    @State private var isPrivacyPolicyPresented = false

    var body: some View {
        VStack(spacing: FootballSpacing.md) {
            CustomNavigationHeader(title: "Settings", subtitle: "Manage refresh behavior, cache, and your default football context.")
            ScrollView {
                VStack(alignment: .leading, spacing: FootballSpacing.lg) {
                    Group {
                        settingCard(title: "Default Context") {
                            Text("Country: \(router.selection.country?.name ?? "Not set")")
                            Text("League: \(router.selection.league?.name ?? "Not set")")
                            Text("Season: \(router.selection.season?.slashDisplay ?? Season.appKickoffDisplay)")
                        }

                        settingCard(title: "Live Refresh Interval") {
                            Text("Adjust how frequently the live center refreshes.")
                                .foregroundStyle(FootballColors.textSecondary)
                            Slider(value: $refreshInterval, in: 15...60, step: 5)
                                .tint(FootballColors.accent)
                            Text("\(Int(refreshInterval)) seconds")
                                .foregroundStyle(FootballColors.textPrimary)
                            FootballSecondaryButton(title: "Save Refresh Preference") {
                                viewModel.saveLiveRefreshInterval(refreshInterval)
                            }
                        }

                        settingCard(title: "Favorites") {
                            if viewModel.favorites.isEmpty {
                                Text("No favorite teams saved.")
                                    .foregroundStyle(FootballColors.textSecondary)
                            } else {
                                ForEach(viewModel.favorites) { favorite in
                                    TeamCard(team: favorite.team, isFavorite: true)
                                }
                            }
                        }

                        settingCard(title: "Cache") {
                            FootballSecondaryButton(title: "Clear Cached Data") {
                                clearCacheResult = viewModel.clearCache()
                            }
                            if !clearCacheResult.isEmpty {
                                Text(clearCacheResult)
                                    .foregroundStyle(FootballColors.textSecondary)
                            }
                        }

                        settingCard(title: "Privacy") {
                            FootballSecondaryButton(title: "Privacy Policy") {
                                isPrivacyPolicyPresented = true
                            }
                        }
                    }
                }
                .padding(FootballSpacing.lg)
            }
        }
        .background(FootballColors.background)
        .sheet(isPresented: $isPrivacyPolicyPresented) {
            UniSportPrivacyPolicyPanel()
        }
    }

    private func settingCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: FootballSpacing.md) {
            Text(title)
                .font(FootballTypography.section)
                .foregroundStyle(FootballColors.textPrimary)
            VStack(alignment: .leading, spacing: FootballSpacing.md) {
                content()
            }
            .footballCardStyle()
        }
    }
}

struct FavoritesScreen: View {
    @ObservedObject var viewModel: LaunchViewModel
    @ObservedObject var router: AppRouter

    var body: some View {
        NavigationStack {
            VStack(spacing: FootballSpacing.md) {
                CustomNavigationHeader(title: "Favorites", subtitle: "Pinned teams and fast re-entry into your preferred football context.")
                ScrollView {
                    VStack(alignment: .leading, spacing: FootballSpacing.lg) {
                        if viewModel.favorites.isEmpty {
                            EmptyStateCard(title: "No Favorites Saved", message: "Star a team from the league browser or team profile to keep it here.", systemImage: "star")
                        } else {
                            ForEach(viewModel.favorites) { favorite in
                                Button {
                                    router.updateSelection(AppContextSelection(country: router.selection.country, season: router.selection.season, league: router.selection.league, team: favorite.team))
                                } label: {
                                    TeamCard(team: favorite.team, isFavorite: true)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(FootballSpacing.lg)
                }
            }
            .background(FootballColors.background)
        }
    }
}

struct MatchTimelineScreen: View {
    @ObservedObject var viewModel: LaunchViewModel
    let fixture: Fixture

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: FootballSpacing.lg) {
                    CustomNavigationHeader(title: "Match Timeline", subtitle: "\(fixture.homeTeam.name) vs \(fixture.awayTeam.name)")
                    HStack(spacing: FootballSpacing.sm) {
                        RemoteBadgeImage(urlString: fixture.homeTeam.logoURL, placeholderText: fixture.homeTeam.name, dimension: 40)
                        Text(fixture.homeTeam.name)
                            .font(FootballTypography.cardTitle)
                            .foregroundStyle(FootballColors.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("–")
                            .font(FootballTypography.body)
                            .foregroundStyle(FootballColors.textSecondary)
                        Text(fixture.awayTeam.name)
                            .font(FootballTypography.cardTitle)
                            .foregroundStyle(FootballColors.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        RemoteBadgeImage(urlString: fixture.awayTeam.logoURL, placeholderText: fixture.awayTeam.name, dimension: 40)
                    }
                    .padding(FootballSpacing.md)
                    .footballCardStyle()
                    switch viewModel.matchDetailState {
                    case .success(let detail, _):
                        ForEach(detail.events) { event in
                            HStack(alignment: .top, spacing: FootballSpacing.sm) {
                                if let t = teamMatchingEventTeam(event.teamName, fixture: fixture) {
                                    RemoteBadgeImage(urlString: t.logoURL, placeholderText: t.name, dimension: 28)
                                }
                                VStack(alignment: .leading, spacing: FootballSpacing.sm) {
                                    Text("\(event.minute)'")
                                        .font(FootballTypography.caption)
                                        .foregroundStyle(FootballColors.accent)
                                    Text(event.type)
                                        .font(FootballTypography.cardTitle)
                                        .foregroundStyle(FootballColors.textPrimary)
                                    Text("\(event.teamName) • \(event.playerName ?? "Unknown Player")")
                                        .font(FootballTypography.body)
                                        .foregroundStyle(FootballColors.textPrimary)
                                    Text(event.detail)
                                        .font(FootballTypography.caption)
                                        .foregroundStyle(FootballColors.textSecondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .footballCardStyle()
                        }
                    default:
                        LoadingPitchView()
                    }
                }
                .padding(FootballSpacing.lg)
            }
            .background(FootballColors.background)
            .task {
                await viewModel.loadMatchDetail(fixtureID: fixture.id)
            }
        }
    }
}

struct TeamStatisticsScreen: View {
    let team: Team
    @ObservedObject var viewModel: LaunchViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: FootballSpacing.lg) {
                    CustomNavigationHeader(title: "Team Statistics", subtitle: team.name)
                    switch viewModel.teamProfileState {
                    case .success(let profile, _):
                        VStack(spacing: FootballSpacing.md) {
                            StatComparisonBar(title: "Goals For vs Against", leftValue: Double(profile.statistics.goalsFor), rightValue: Double(profile.statistics.goalsAgainst), suffix: "")
                            StatComparisonBar(title: "Wins vs Draws", leftValue: Double(profile.statistics.wins), rightValue: Double(profile.statistics.draws), suffix: "")
                            StatComparisonBar(title: "Average Possession", leftValue: profile.statistics.averagePossession, rightValue: 100 - profile.statistics.averagePossession, suffix: "%")
                            StatComparisonBar(title: "Average Shots", leftValue: profile.statistics.averageShots, rightValue: max(1, 20 - profile.statistics.averageShots), suffix: "")
                        }
                        .footballCardStyle()
                    default:
                        LoadingPitchView()
                    }
                }
                .padding(FootballSpacing.lg)
            }
            .background(FootballColors.background)
        }
    }
}

struct PlayerStatisticsScreen: View {
    let team: Team
    @ObservedObject var viewModel: LaunchViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: FootballSpacing.lg) {
                    CustomNavigationHeader(title: "Player Statistics", subtitle: team.name)
                    switch viewModel.teamProfileState {
                    case .success(let profile, _):
                        ForEach(profile.squad) { player in
                            HStack(spacing: FootballSpacing.md) {
                                RemoteBadgeImage(urlString: player.photoURL, placeholderText: player.playerName)
                                    .frame(width: 56, height: 56)
                                VStack(alignment: .leading, spacing: FootballSpacing.sm) {
                                    Text(player.playerName)
                                        .font(FootballTypography.cardTitle)
                                        .foregroundStyle(FootballColors.textPrimary)
                                        .lineLimit(1)
                                    Text("\(player.position) • Rating \(player.rating.map { String(format: "%.1f", $0) } ?? "N/A")")
                                        .font(FootballTypography.caption)
                                        .foregroundStyle(FootballColors.textSecondary)
                                        .lineLimit(1)
                                    HStack {
                                        Text("Goals \(player.goals)")
                                        Text("Assists \(player.assists)")
                                        Text("Minutes \(player.minutes)")
                                    }
                                    .font(FootballTypography.body)
                                    .foregroundStyle(FootballColors.textPrimary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
                            .footballCardStyle()
                        }
                    default:
                        LoadingPitchView()
                    }
                }
                .padding(FootballSpacing.lg)
            }
            .background(FootballColors.background)
        }
    }
}
