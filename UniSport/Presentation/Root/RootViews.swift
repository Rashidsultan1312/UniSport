import SwiftUI

struct RootAppView: View {
    @StateObject private var router: AppRouter
    @StateObject private var viewModel: LaunchViewModel

    init(container: AppContainer) {
        _router = StateObject(wrappedValue: AppRouter(settingsRepository: container.settingsRepository))
        _viewModel = StateObject(wrappedValue: LaunchViewModel(container: container))
    }

    var body: some View {
        ZStack {
            FootballColors.background.ignoresSafeArea()
            switch router.bootstrapState {
            case .launching:
                LoadingPitchView()
                    .task {
                        await router.bootstrap()
                        await viewModel.loadFilters(selection: router.selection)
                    }
            case .onboarding:
                WelcomeFlowView(router: router, viewModel: viewModel)
            case .ready:
                MainTabShell(router: router, viewModel: viewModel)
            case .failed(let message):
                ErrorRetryCard(title: "Bootstrap Failed", message: message) {
                    Task {
                        await router.bootstrap()
                    }
                }
                .padding(FootballSpacing.lg)
            }
        }
        .preferredColorScheme(.light)
    }
}

struct WelcomeFlowView: View {
    @ObservedObject var router: AppRouter
    @ObservedObject var viewModel: LaunchViewModel
    @State private var selectedCountry: Country?
    @State private var selectedSeason: Season?
    @State private var selectedLeague: League?
    @State private var selectedTeam: Team?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FootballSpacing.xl) {
                VStack(alignment: .leading, spacing: FootballSpacing.md) {
                    Text("Football Analytics Command Center")
                        .font(FootballTypography.hero)
                        .foregroundStyle(FootballColors.textPrimary)
                    Text("Select your core football context and unlock a premium dashboard for live data, standings, fixtures, and team intelligence.")
                        .font(FootballTypography.body)
                        .foregroundStyle(FootballColors.textSecondary)
                }

                selectionBlock(title: "Country") {
                    WrapCollection(items: viewModel.countries, selectedItem: $selectedCountry) { country in
                        FilterChip(title: country.name, isSelected: selectedCountry == country)
                    }
                }

                selectionBlock(title: "Season") {
                    WrapCollection(items: viewModel.seasons, selectedItem: $selectedSeason) { season in
                        FilterChip(title: season.slashDisplay, isSelected: selectedSeason == season)
                    }
                }

                selectionBlock(title: "League") {
                    ForEach(filteredLeagues) { league in
                        Button {
                            selectedLeague = league
                        } label: {
                            LeagueCard(league: league)
                                .overlay(
                                    RoundedRectangle(cornerRadius: FootballRadius.card, style: .continuous)
                                        .stroke(selectedLeague == league ? FootballColors.accent : .clear, lineWidth: 1.5)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                selectionBlock(title: "Favorite Team") {
                    ForEach(filteredTeams) { team in
                        Button {
                            selectedTeam = team
                        } label: {
                            TeamCard(team: team, isFavorite: selectedTeam == team)
                                .overlay(
                                    RoundedRectangle(cornerRadius: FootballRadius.card, style: .continuous)
                                        .stroke(selectedTeam == team ? FootballColors.accent : .clear, lineWidth: 1.5)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                FootballPrimaryButton(title: "Enter Dashboard") {
                    let selection = AppContextSelection(country: selectedCountry, season: selectedSeason, league: selectedLeague, team: selectedTeam)
                    router.completeOnboarding(selection: selection)
                }

                FootballSecondaryButton(title: "Use Recommended Setup") {
                    let country = viewModel.countries.first
                    let season = viewModel.seasons.first
                    let league = filteredLeagues.first ?? viewModel.leagues.first
                    let team = filteredTeams.first
                    router.completeOnboarding(selection: AppContextSelection(country: country, season: season, league: league, team: team))
                }
            }
            .padding(FootballSpacing.lg)
        }
        .background(FootballColors.background.ignoresSafeArea())
        .task {
            selectedCountry = viewModel.countries.first
            selectedSeason = viewModel.seasons.first
            selectedLeague = filteredLeagues.first ?? viewModel.leagues.first
            selectedTeam = filteredTeams.first
        }
    }

    private var filteredLeagues: [League] {
        viewModel.leagues.filter { league in
            (selectedCountry == nil || league.country == selectedCountry) && (selectedSeason == nil || league.currentSeason == selectedSeason)
        }
    }

    private var filteredTeams: [Team] {
        guard selectedLeague != nil else { return viewModel.teams }
        return viewModel.teams
    }

    private func selectionBlock<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: FootballSpacing.md) {
            Text(title)
                .font(FootballTypography.section)
                .foregroundStyle(FootballColors.textPrimary)
            content()
        }
    }
}

struct MainTabShell: View {
    @ObservedObject var router: AppRouter
    @ObservedObject var viewModel: LaunchViewModel

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch router.selectedTab {
                case .home:
                    HomeDashboardScreen(router: router, viewModel: viewModel)
                case .live:
                    LiveScoresScreen(router: router, viewModel: viewModel)
                case .leagues:
                    LeagueHubScreen(router: router, viewModel: viewModel)
                case .search:
                    SearchScreen(router: router, viewModel: viewModel)
                case .settings:
                    SettingsScreen(router: router, viewModel: viewModel)
                }
            }
            CustomTabBar(selectedTab: $router.selectedTab)
        }
        .background(FootballColors.background.ignoresSafeArea())
    }
}

struct HomeDashboardScreen: View {
    @ObservedObject var router: AppRouter
    @ObservedObject var viewModel: LaunchViewModel
    @State private var selectedFixture: Fixture?
    @State private var selectedTeam: Team?
    @State private var showFavorites = false
    @State private var showComingSoonModal = false
    @State private var pendingSportName = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: FootballSpacing.md) {
                CustomNavigationHeader(
                    title: "UniSport",
                    subtitle: "\(router.selection.league?.name ?? "Select League") • \(router.selection.season?.slashDisplay ?? Season.appKickoffDisplay)",
                    trailing: AnyView(
                        HStack(spacing: FootballSpacing.sm) {
                            Button {
                                router.selectedTab = .leagues
                            } label: {
                                Image(systemName: "shield.fill")
                                    .foregroundStyle(FootballColors.accent)
                                    .padding(10)
                                    .background(FootballColors.surfaceSecondary)
                                    .clipShape(Circle())
                            }
                            Button {
                                showFavorites = true
                            } label: {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(FootballColors.warning)
                                    .padding(10)
                                    .background(FootballColors.surfaceSecondary)
                                    .clipShape(Circle())
                            }
                        }
                    )
                )
                ScrollView {
                    VStack(alignment: .leading, spacing: FootballSpacing.lg) {
                        sportSelectorSection
                        content
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(.horizontal, FootballSpacing.lg)
                    .padding(.bottom, FootballSpacing.hero)
                }
            }
            .refreshable {
                await viewModel.refreshHome(selection: router.selection)
            }
            .task {
                await viewModel.refreshHome(selection: router.selection)
            }
            .sheet(item: $selectedFixture) { fixture in
                MatchDetailScreen(viewModel: viewModel, router: router, fixture: fixture)
            }
            .sheet(item: $selectedTeam) { team in
                TeamProfileScreen(viewModel: viewModel, router: router, team: team)
            }
            .navigationDestination(isPresented: $showFavorites) {
                FavoritesScreen(viewModel: viewModel, router: router)
            }
            .alert("Coming Soon", isPresented: $showComingSoonModal) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("\(pendingSportName) will be available soon.")
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.dashboardState {
        case .idle, .loading:
            LoadingPitchView()
                .frame(height: 320)
        case .failure(let message):
            ErrorRetryCard(title: "Dashboard Unavailable", message: message) {
                Task { await viewModel.refreshHome(selection: router.selection) }
            }
            .padding(.horizontal, FootballSpacing.lg)
        case .empty(let message):
            EmptyStateCard(title: "No Matches Today", message: message, systemImage: "calendar")
                .padding(.horizontal, FootballSpacing.lg)
        case .success(let data, _):
            VStack(alignment: .leading, spacing: FootballSpacing.lg) {
                suggestedLeaguesSection(dashboard: data)
                upcomingMatchesSection(fixtures: data.upcomingFixtures)
                fixturesCarousel(title: "Latest Results", fixtures: data.finishedFixtures)
                if !data.liveFixtures.isEmpty {
                    fixturesCarousel(title: "Live Match Center", fixtures: data.liveFixtures, live: true)
                }
                statsSection(data.featuredStats)
                favoritesSection(data.favoriteTeams)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, FootballSpacing.lg)
        }
    }

    private func favoritesSection(_ favorites: [FavoriteTeam]) -> some View {
        VStack(alignment: .leading, spacing: FootballSpacing.md) {
            sectionTitle("Favorite Teams")
            if favorites.isEmpty {
                EmptyStateCard(title: "No Favorites Yet", message: "Add a team to pin its matches and stats to the dashboard.", systemImage: "star")
            } else {
                ForEach(favorites) { favorite in
                    Button {
                        selectedTeam = favorite.team
                    } label: {
                        TeamCard(team: favorite.team, isFavorite: true)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func suggestedLeaguesSection(dashboard: DashboardData) -> some View {
        let leagues = dashboard.recommendedLeagues.isEmpty ? viewModel.leagues : dashboard.recommendedLeagues
        return VStack(alignment: .leading, spacing: FootballSpacing.md) {
            HStack {
                sectionTitle("Suggested Leagues")
                Spacer()
                Button("See all") {
                    router.selectedTab = .leagues
                }
                .foregroundStyle(FootballColors.accent)
            }
            ForEach(leagues.prefix(4)) { league in
                LeagueCard(league: league)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sportSelectorSection: some View {
        VStack(alignment: .leading, spacing: FootballSpacing.md) {
            sectionTitle("Sports")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: FootballSpacing.sm) {
                    FilterChip(title: "Football", isSelected: true)
                    Button {
                        pendingSportName = "Basketball"
                        showComingSoonModal = true
                    } label: {
                        FilterChip(title: "Basketball", isSelected: false)
                    }
                    .buttonStyle(.plain)
                    Button {
                        pendingSportName = "Tennis"
                        showComingSoonModal = true
                    } label: {
                        FilterChip(title: "Tennis", isSelected: false)
                    }
                    .buttonStyle(.plain)
                    Button {
                        pendingSportName = "Hockey"
                        showComingSoonModal = true
                    } label: {
                        FilterChip(title: "Hockey", isSelected: false)
                    }
                    .buttonStyle(.plain)
                    Button {
                        pendingSportName = "Volleyball"
                        showComingSoonModal = true
                    } label: {
                        FilterChip(title: "Volleyball", isSelected: false)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func upcomingMatchesSection(fixtures: [Fixture]) -> some View {
        VStack(alignment: .leading, spacing: FootballSpacing.md) {
            sectionTitle("Upcoming Matches")
            if fixtures.isEmpty {
                EmptyStateCard(title: "No Data", message: "This section will update as match data becomes available.", systemImage: "waveform.path.ecg")
            } else {
                ForEach(fixtures) { fixture in
                    Button {
                        selectedFixture = fixture
                    } label: {
                        MatchCard(fixture: fixture)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func fixturesCarousel(title: String, fixtures: [Fixture], live: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: FootballSpacing.md) {
            sectionTitle(title)
            if fixtures.isEmpty {
                EmptyStateCard(title: "No Data", message: "This section will update as match data becomes available.", systemImage: "waveform.path.ecg")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: FootballSpacing.md) {
                        ForEach(fixtures) { fixture in
                            Button {
                                selectedFixture = fixture
                            } label: {
                                Group {
                                    if live {
                                        LiveScoreCard(fixture: fixture)
                                            .frame(width: 280)
                                    } else {
                                        MatchCard(fixture: fixture)
                                            .frame(width: 320)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statsSection(_ stats: [TeamStatistic]) -> some View {
        VStack(alignment: .leading, spacing: FootballSpacing.md) {
            sectionTitle("Mini Analytics")
            VStack(spacing: FootballSpacing.md) {
                ForEach(stats) { stat in
                    StatComparisonBar(title: stat.title, leftValue: stat.homeValue, rightValue: stat.awayValue, suffix: stat.suffix)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .footballCardStyle()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(FootballTypography.section)
            .foregroundStyle(FootballColors.textPrimary)
    }

    private func compactStandingRow(_ row: StandingRow) -> some View {
        HStack(spacing: FootballSpacing.sm) {
            Text("\(row.rank)")
                .font(FootballTypography.caption.weight(.semibold))
                .foregroundStyle(FootballColors.accent)
                .frame(width: 18, alignment: .leading)

            RemoteBadgeImage(urlString: row.team.logoURL, placeholderText: row.team.name, dimension: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(row.team.name)
                    .font(FootballTypography.body.weight(.semibold))
                    .foregroundStyle(FootballColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                FormBadge(results: row.form)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(row.points) pts")
                    .font(FootballTypography.body.weight(.semibold))
                    .foregroundStyle(FootballColors.textPrimary)
                Text("\(row.played)P • \(row.goalDifference >= 0 ? "+" : "")\(row.goalDifference) GD")
                    .font(FootballTypography.caption)
                    .foregroundStyle(FootballColors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, FootballSpacing.sm)
    }
}

struct LeagueHubScreen: View {
    @ObservedObject var router: AppRouter
    @ObservedObject var viewModel: LaunchViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: FootballSpacing.md) {
                CustomNavigationHeader(
                    title: "League Browser",
                    subtitle: "Browse standings, fixtures, and stats for each league."
                )
                ScrollView {
                    VStack(alignment: .leading, spacing: FootballSpacing.lg) {
                        sectionTitle("Leagues")
                        ForEach(viewModel.leagues) { league in
                            NavigationLink {
                                LeagueDetailScreen(router: router, viewModel: viewModel, league: league)
                            } label: {
                                LeagueCard(league: league)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(.horizontal, FootballSpacing.xl)
                    .padding(.bottom, FootballSpacing.hero)
                }
            }
            .background(FootballColors.background)
            .task {
                await viewModel.loadFilters(selection: router.selection)
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(FootballTypography.section)
            .foregroundStyle(FootballColors.textPrimary)
    }
}

struct LeagueDetailScreen: View {
    @ObservedObject var router: AppRouter
    @ObservedObject var viewModel: LaunchViewModel
    let league: League
    @State private var selectedTeam: Team?
    @State private var selectedFixture: Fixture?

    var body: some View {
        VStack(spacing: FootballSpacing.md) {
            CustomNavigationHeader(
                title: league.name,
                subtitle: "\(league.country.name) • \(router.selection.season?.slashDisplay ?? league.currentSeason.slashDisplay)",
                trailing: AnyView(
                    Button {
                        router.selectedTab = .search
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(FootballColors.accent)
                            .padding(10)
                            .background(FootballColors.surfaceSecondary)
                            .clipShape(Circle())
                    }
                )
            )
            ScrollView {
                VStack(alignment: .leading, spacing: FootballSpacing.lg) {
                    StandingsScreen(router: router, viewModel: viewModel, selectedTeam: $selectedTeam)
                    MatchBucketsScreen(router: router, viewModel: viewModel, selectedFixture: $selectedFixture)
                }
                .padding(.horizontal, FootballSpacing.xl)
                .padding(.bottom, FootballSpacing.hero)
            }
        }
        .background(FootballColors.background)
        .sheet(item: $selectedTeam) { team in
            TeamProfileScreen(viewModel: viewModel, router: router, team: team)
        }
        .sheet(item: $selectedFixture) { fixture in
            MatchDetailScreen(viewModel: viewModel, router: router, fixture: fixture)
        }
        .task {
            router.updateSelection(AppContextSelection(country: league.country, season: router.selection.season ?? league.currentSeason, league: league, team: nil))
            await viewModel.loadFilters(selection: router.selection)
            await viewModel.refreshStandings(selection: router.selection)
            await viewModel.refreshFixtures(selection: router.selection)
        }
    }
}

struct MatchBucketsScreen: View {
    @ObservedObject var router: AppRouter
    @ObservedObject var viewModel: LaunchViewModel
    @Binding var selectedFixture: Fixture?

    var body: some View {
        VStack(alignment: .leading, spacing: FootballSpacing.md) {
            Text("Matches")
                .font(FootballTypography.section)
                .foregroundStyle(FootballColors.textPrimary)
            switch viewModel.fixturesState {
            case .idle, .loading:
                LoadingPitchView().frame(height: 220)
            case .empty(let message):
                EmptyStateCard(title: "No Matches", message: message, systemImage: "calendar")
            case .failure(let message):
                ErrorRetryCard(title: "Matches Failed", message: message) {
                    Task { await viewModel.refreshFixtures(selection: router.selection, status: nil) }
                }
            case .success(let fixtures, _):
                matchBlock(title: "Upcoming", fixtures: fixtures.filter(\.isUpcomingMatch))
                matchBlock(title: "Results", fixtures: fixtures.filter { $0.status == .finished })
            }
        }
    }

    private func matchBlock(title: String, fixtures: [Fixture]) -> some View {
        VStack(alignment: .leading, spacing: FootballSpacing.sm) {
            Text(title)
                .font(FootballTypography.cardTitle)
                .foregroundStyle(FootballColors.textPrimary)
            if fixtures.isEmpty {
                EmptyStateCard(title: "No \(title)", message: "Data will appear once API returns matches.", systemImage: "clock")
            } else {
                ForEach(fixtures.prefix(8)) { fixture in
                    Button {
                        selectedFixture = fixture
                    } label: {
                        MatchCard(fixture: fixture)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct TeamSelectionScreen: View {
    @ObservedObject var router: AppRouter
    @ObservedObject var viewModel: LaunchViewModel
    @Binding var selectedTeam: Team?

    var body: some View {
        VStack(alignment: .leading, spacing: FootballSpacing.md) {
            Text("Team Selector")
                .font(FootballTypography.section)
                .foregroundStyle(FootballColors.textPrimary)
            ForEach(viewModel.teams) { team in
                Button {
                    router.updateSelection(AppContextSelection(country: router.selection.country, season: router.selection.season, league: router.selection.league, team: team))
                    selectedTeam = team
                } label: {
                    TeamCard(team: team, isFavorite: viewModel.favorites.contains(where: { $0.team.id == team.id }))
                }
                .contextMenu {
                    Button("Toggle Favorite") {
                        guard let leagueID = router.selection.league?.id,
                              let season = router.selection.season?.year else { return }
                        viewModel.toggleFavorite(team: team, leagueID: leagueID, seasonYear: season)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct FixturesScreen: View {
    @ObservedObject var router: AppRouter
    @ObservedObject var viewModel: LaunchViewModel
    @Binding var selectedFixture: Fixture?
    @State private var statusFilter: MatchStatus? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: FootballSpacing.md) {
            Text("Fixtures & Scores")
                .font(FootballTypography.section)
                .foregroundStyle(FootballColors.textPrimary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: FootballSpacing.sm) {
                    Button {
                        statusFilter = nil
                        Task { await viewModel.refreshFixtures(selection: router.selection, status: nil) }
                    } label: {
                        FilterChip(title: "All", isSelected: statusFilter == nil)
                    }
                    .buttonStyle(.plain)
                    ForEach(MatchStatus.allCases, id: \.rawValue) { status in
                        Button {
                            statusFilter = status
                            Task { await viewModel.refreshFixtures(selection: router.selection, status: status) }
                        } label: {
                            FilterChip(title: status.title, isSelected: statusFilter == status)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            switch viewModel.fixturesState {
            case .idle, .loading:
                LoadingPitchView().frame(height: 240)
            case .empty(let message):
                EmptyStateCard(title: "No Fixtures", message: message, systemImage: "calendar.badge.exclamationmark")
            case .failure(let message):
                ErrorRetryCard(title: "Fixtures Unavailable", message: message) {
                    Task { await viewModel.refreshFixtures(selection: router.selection, status: statusFilter) }
                }
            case .success(let fixtures, _):
                ForEach(fixtures) { fixture in
                    Button {
                        selectedFixture = fixture
                    } label: {
                        MatchCard(fixture: fixture)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct StandingsScreen: View {
    @ObservedObject var router: AppRouter
    @ObservedObject var viewModel: LaunchViewModel
    @Binding var selectedTeam: Team?

    var body: some View {
        VStack(alignment: .leading, spacing: FootballSpacing.md) {
            Text("Standings")
                .font(FootballTypography.section)
                .foregroundStyle(FootballColors.textPrimary)
            switch viewModel.standingsState {
            case .idle, .loading:
                LoadingPitchView().frame(height: 220)
            case .empty(let message):
                EmptyStateCard(title: "Standings Unavailable", message: message, systemImage: "tablecells")
            case .failure(let message):
                ErrorRetryCard(title: "Standings Failed", message: message) {
                    Task { await viewModel.refreshStandings(selection: router.selection) }
                }
            case .success(let rows, _):
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(rows) { row in
                        Button {
                            selectedTeam = row.team
                        } label: {
                            compactLeagueStandingRow(row)
                        }
                        .buttonStyle(.plain)
                        Divider().background(FootballColors.divider)
                    }
                }
                .footballCardStyle()
            }
        }
    }

    private func compactLeagueStandingRow(_ row: StandingRow) -> some View {
        VStack(alignment: .leading, spacing: FootballSpacing.sm) {
            HStack(spacing: FootballSpacing.sm) {
                Text("\(row.rank)")
                    .font(FootballTypography.caption.weight(.semibold))
                    .foregroundStyle(FootballColors.accent)
                    .frame(width: 18, alignment: .leading)

                RemoteBadgeImage(urlString: row.team.logoURL, placeholderText: row.team.name, dimension: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text(row.team.name)
                        .font(FootballTypography.body.weight(.semibold))
                        .foregroundStyle(FootballColors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text("\(row.points) pts • \(row.played) played")
                        .font(FootballTypography.caption)
                        .foregroundStyle(FootballColors.textSecondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(row.won)-\(row.drawn)-\(row.lost)")
                        .font(FootballTypography.body.weight(.semibold))
                        .foregroundStyle(FootballColors.textPrimary)
                    Text("W-D-L")
                        .font(FootballTypography.tiny)
                        .foregroundStyle(FootballColors.textSecondary)
                }
            }

            HStack(alignment: .center) {
                FormBadge(results: row.form)
                Spacer()
                Text("GF \(row.goalsFor)")
                    .font(FootballTypography.caption)
                    .foregroundStyle(FootballColors.textSecondary)
                Text("GA \(row.goalsAgainst)")
                    .font(FootballTypography.caption)
                    .foregroundStyle(FootballColors.textSecondary)
                Text("GD \(row.goalDifference >= 0 ? "+" : "")\(row.goalDifference)")
                    .font(FootballTypography.caption.weight(.semibold))
                    .foregroundStyle(row.goalDifference >= 0 ? FootballColors.accent : FootballColors.textPrimary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, FootballSpacing.md)
    }
}

struct LiveScoresScreen: View {
    @ObservedObject var router: AppRouter
    @ObservedObject var viewModel: LaunchViewModel
    @State private var selectedFixture: Fixture?
    @StateObject private var refreshManager = LiveRefreshManager()

    var body: some View {
        NavigationStack {
            VStack(spacing: FootballSpacing.md) {
                CustomNavigationHeader(title: "Live Match Center", subtitle: "Real-time scorecards, match momentum, and quick drill-down.")
                ScrollView {
                    VStack(alignment: .leading, spacing: FootballSpacing.lg) {
                        switch viewModel.liveState {
                        case .idle, .loading:
                            LoadingPitchView().frame(height: 280)
                        case .empty(let message):
                            EmptyStateCard(title: "No Live Matches Right Now", message: message, systemImage: "dot.radiowaves.left.and.right")
                        case .failure(let message):
                            ErrorRetryCard(title: "Live Feed Unavailable", message: message) {
                                Task { await viewModel.refreshLive() }
                            }
                        case .success(let fixtures, _):
                            Text("\(fixtures.count) live fixtures")
                                .font(FootballTypography.section)
                                .foregroundStyle(FootballColors.textPrimary)
                            ForEach(fixtures) { fixture in
                                Button {
                                    selectedFixture = fixture
                                } label: {
                                    LiveScoreCard(fixture: fixture)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(FootballSpacing.lg)
                }
            }
            .background(FootballColors.background)
            .refreshable {
                await viewModel.refreshLive()
            }
            .task {
                await viewModel.refreshLive()
                refreshManager.start(interval: 20) {
                    await viewModel.refreshLive()
                }
            }
            .onDisappear {
                refreshManager.stop()
            }
            .sheet(item: $selectedFixture) { fixture in
                MatchDetailScreen(viewModel: viewModel, router: router, fixture: fixture)
            }
        }
    }
}

struct MatchDetailScreen: View {
    @ObservedObject var viewModel: LaunchViewModel
    @ObservedObject var router: AppRouter
    let fixture: Fixture
    @State private var selectedTeam: Team?
    @State private var showTimeline = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FootballSpacing.lg) {
                VStack(alignment: .leading, spacing: FootballSpacing.md) {
                    HStack(alignment: .top, spacing: FootballSpacing.lg) {
                        VStack(spacing: FootballSpacing.sm) {
                            RemoteBadgeImage(urlString: fixture.homeTeam.logoURL, placeholderText: fixture.homeTeam.name, dimension: 52)
                            Text(fixture.homeTeam.name)
                                .font(FootballTypography.cardTitle)
                                .foregroundStyle(FootballColors.textPrimary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.85)
                        }
                        .frame(maxWidth: .infinity)
                        Text("vs")
                            .font(FootballTypography.body.weight(.bold))
                            .foregroundStyle(FootballColors.textSecondary)
                            .padding(.top, FootballSpacing.sm)
                        VStack(spacing: FootballSpacing.sm) {
                            RemoteBadgeImage(urlString: fixture.awayTeam.logoURL, placeholderText: fixture.awayTeam.name, dimension: 52)
                            Text(fixture.awayTeam.name)
                                .font(FootballTypography.cardTitle)
                                .foregroundStyle(FootballColors.textPrimary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.85)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    ScorePill(status: fixture.statusDisplay, homeScore: fixture.score.home, awayScore: fixture.score.away)
                    Text("\(fixture.venue ?? "Venue TBC") • \(DateFormatters.matchDate.string(from: fixture.date))")
                        .font(FootballTypography.body)
                        .foregroundStyle(FootballColors.textSecondary)
                }
                .footballCardStyle()

                switch viewModel.matchDetailState {
                case .idle, .loading:
                    LoadingPitchView().frame(height: 300)
                case .empty(let message):
                    EmptyStateCard(title: "No Match Detail", message: message, systemImage: "soccerball")
                case .failure(let message):
                    ErrorRetryCard(title: "Match Detail Failed", message: message) {
                        Task { await viewModel.loadMatchDetail(fixtureID: fixture.id) }
                    }
                case .success(let detail, _):
                    VStack(alignment: .leading, spacing: FootballSpacing.lg) {
                        detailBlock(title: "Match Statistics") {
                            VStack(spacing: FootballSpacing.md) {
                                ForEach(detail.statistics) { stat in
                                    StatComparisonBar(title: stat.title, leftValue: stat.homeValue, rightValue: stat.awayValue, suffix: stat.suffix)
                                }
                            }
                        }

                        detailBlock(title: "Timeline") {
                            ForEach(detail.events) { event in
                                HStack(alignment: .top, spacing: FootballSpacing.sm) {
                                    if let t = teamMatchingEventTeam(event.teamName, fixture: fixture) {
                                        RemoteBadgeImage(urlString: t.logoURL, placeholderText: t.name, dimension: 26)
                                    }
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("\(event.minute)' • \(event.type)")
                                            .font(FootballTypography.caption)
                                            .foregroundStyle(FootballColors.accent)
                                        Text("\(event.teamName) • \(event.playerName ?? "Unknown Player")")
                                            .font(FootballTypography.body.weight(.semibold))
                                            .foregroundStyle(FootballColors.textPrimary)
                                        Text(event.detail)
                                            .font(FootballTypography.caption)
                                            .foregroundStyle(FootballColors.textSecondary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                if event.id != detail.events.last?.id {
                                    Divider().background(FootballColors.divider)
                                }
                            }
                        }

                        detailBlock(title: "Lineups") {
                            ForEach(detail.lineups) { lineup in
                                VStack(alignment: .leading, spacing: FootballSpacing.sm) {
                                    HStack(spacing: FootballSpacing.sm) {
                                        RemoteBadgeImage(urlString: lineup.team.logoURL, placeholderText: lineup.team.name, dimension: 34)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(lineup.team.name)
                                                .font(FootballTypography.cardTitle)
                                                .foregroundStyle(FootballColors.textPrimary)
                                                .lineLimit(1)
                                            Text(lineup.formation)
                                                .font(FootballTypography.caption)
                                                .foregroundStyle(FootballColors.textSecondary)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    Text("Coach: \(lineup.coach)")
                                        .font(FootballTypography.caption)
                                        .foregroundStyle(FootballColors.textSecondary)
                                    ForEach(lineup.startXI) { player in
                                        Text("\(player.number ?? 0) • \(player.name) • \(player.position)")
                                            .font(FootballTypography.body)
                                            .foregroundStyle(FootballColors.textPrimary)
                                    }
                                }
                                .footballCardStyle()
                            }
                        }

                        detailBlock(title: "Related Fixtures") {
                            ForEach(detail.relatedFixtures) { related in
                                MatchCard(fixture: related)
                            }
                        }

                        HStack(spacing: FootballSpacing.md) {
                            Button {
                                selectedTeam = fixture.homeTeam
                            } label: {
                                HStack(spacing: FootballSpacing.sm) {
                                    RemoteBadgeImage(urlString: fixture.homeTeam.logoURL, placeholderText: fixture.homeTeam.name, dimension: 28)
                                    Text(fixture.homeTeam.name)
                                        .font(FootballTypography.body.weight(.semibold))
                                        .foregroundStyle(FootballColors.textPrimary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.85)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, FootballSpacing.md)
                                .padding(.horizontal, FootballSpacing.sm)
                                .background(FootballColors.surfaceSecondary)
                                .clipShape(RoundedRectangle(cornerRadius: FootballRadius.standard, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: FootballRadius.standard, style: .continuous)
                                        .stroke(FootballColors.divider, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)

                            Button {
                                selectedTeam = fixture.awayTeam
                            } label: {
                                HStack(spacing: FootballSpacing.sm) {
                                    RemoteBadgeImage(urlString: fixture.awayTeam.logoURL, placeholderText: fixture.awayTeam.name, dimension: 28)
                                    Text(fixture.awayTeam.name)
                                        .font(FootballTypography.body.weight(.semibold))
                                        .foregroundStyle(FootballColors.textPrimary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.85)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, FootballSpacing.md)
                                .padding(.horizontal, FootballSpacing.sm)
                                .background(FootballColors.surfaceSecondary)
                                .clipShape(RoundedRectangle(cornerRadius: FootballRadius.standard, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: FootballRadius.standard, style: .continuous)
                                        .stroke(FootballColors.divider, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        FootballPrimaryButton(title: "Open Match Timeline") {
                            showTimeline = true
                        }
                    }
                }
            }
            .padding(FootballSpacing.lg)
        }
        .background(FootballColors.background)
        .task {
            await viewModel.loadMatchDetail(fixtureID: fixture.id)
        }
        .sheet(item: $selectedTeam) { team in
            TeamProfileScreen(viewModel: viewModel, router: router, team: team)
        }
        .sheet(isPresented: $showTimeline) {
            MatchTimelineScreen(viewModel: viewModel, fixture: fixture)
        }
    }

    private func detailBlock<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: FootballSpacing.md) {
            Text(title)
                .font(FootballTypography.section)
                .foregroundStyle(FootballColors.textPrimary)
            content()
        }
    }
}

struct TeamProfileScreen: View {
    @ObservedObject var viewModel: LaunchViewModel
    @ObservedObject var router: AppRouter
    let team: Team
    @State private var showStatistics = false
    @State private var showPlayers = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FootballSpacing.lg) {
                switch viewModel.teamProfileState {
                case .idle, .loading:
                    LoadingPitchView().frame(height: 320)
                case .empty(let message):
                    EmptyStateCard(title: "No Team Profile", message: message, systemImage: "person.3")
                case .failure(let message):
                    ErrorRetryCard(title: "Team Profile Failed", message: message) {
                        Task { await load() }
                    }
                case .success(let profile, _):
                    VStack(alignment: .leading, spacing: FootballSpacing.md) {
                        TeamCard(team: profile.team, isFavorite: viewModel.favorites.contains(where: { $0.team.id == profile.team.id }))
                        Text(profile.league.name)
                            .font(FootballTypography.body)
                            .foregroundStyle(FootballColors.textSecondary)
                        FormBadge(results: profile.recentForm)
                    }
                    .footballCardStyle()

                    detail(title: "Upcoming Matches") {
                        ForEach(profile.upcomingFixtures) { fixture in
                            MatchCard(fixture: fixture)
                        }
                    }

                    detail(title: "Statistics") {
                        VStack(spacing: FootballSpacing.md) {
                            StatComparisonBar(title: "Wins vs Losses", leftValue: Double(profile.statistics.wins), rightValue: Double(profile.statistics.losses), suffix: "")
                            StatComparisonBar(title: "Goals For vs Against", leftValue: Double(profile.statistics.goalsFor), rightValue: Double(profile.statistics.goalsAgainst), suffix: "")
                            StatComparisonBar(title: "Average Possession", leftValue: profile.statistics.averagePossession, rightValue: 100 - profile.statistics.averagePossession, suffix: "%")
                        }
                    }

                    detail(title: "Squad") {
                        ForEach(profile.squad) { player in
                            HStack(spacing: FootballSpacing.md) {
                                RemoteBadgeImage(urlString: player.photoURL, placeholderText: player.playerName)
                                    .frame(width: 56, height: 56)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(player.playerName)
                                        .font(FootballTypography.cardTitle)
                                        .foregroundStyle(FootballColors.textPrimary)
                                        .lineLimit(1)
                                    Text("\(player.position) • Goals \(player.goals) • Assists \(player.assists) • Minutes \(player.minutes)")
                                        .font(FootballTypography.caption)
                                        .foregroundStyle(FootballColors.textSecondary)
                                        .lineLimit(2)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
                            .footballCardStyle()
                        }
                    }

                    HStack(spacing: FootballSpacing.md) {
                        FootballSecondaryButton(title: "Team Statistics") {
                            showStatistics = true
                        }
                        FootballSecondaryButton(title: "Player Statistics") {
                            showPlayers = true
                        }
                    }
                }
            }
            .padding(FootballSpacing.lg)
        }
        .background(FootballColors.background)
        .task {
            await load()
        }
        .sheet(isPresented: $showStatistics) {
            TeamStatisticsScreen(team: team, viewModel: viewModel)
        }
        .sheet(isPresented: $showPlayers) {
            PlayerStatisticsScreen(team: team, viewModel: viewModel)
        }
    }

    private func load() async {
        guard let leagueID = router.selection.league?.id,
              let season = router.selection.season?.year else { return }
        await viewModel.loadTeamProfile(teamID: team.id, leagueID: leagueID, season: season)
    }

    private func detail<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: FootballSpacing.md) {
            Text(title)
                .font(FootballTypography.section)
                .foregroundStyle(FootballColors.textPrimary)
            content()
        }
    }
}

struct TopScorersScreen: View {
    @ObservedObject var viewModel: LaunchViewModel
    @ObservedObject var router: AppRouter

    var body: some View {
        VStack(alignment: .leading, spacing: FootballSpacing.md) {
            Text("Top Scorers")
                .font(FootballTypography.section)
                .foregroundStyle(FootballColors.textPrimary)
            switch viewModel.topScorersState {
            case .idle, .loading:
                LoadingPitchView().frame(height: 220)
            case .empty(let message):
                EmptyStateCard(title: "No Top Scorers", message: message, systemImage: "figure.soccer")
            case .failure(let message):
                ErrorRetryCard(title: "Top Scorers Failed", message: message) {
                    guard let leagueID = router.selection.league?.id,
                          let season = router.selection.season?.year else { return }
                    Task { await viewModel.loadTopScorers(leagueID: leagueID, season: season) }
                }
            case .success(let scorers, _):
                ForEach(Array(scorers.enumerated()), id: \.offset) { index, scorer in
                    HStack(spacing: FootballSpacing.md) {
                        Text("\(index + 1)")
                            .frame(width: 24, alignment: .leading)
                            .foregroundStyle(FootballColors.accent)
                        RemoteBadgeImage(urlString: scorer.photoURL, placeholderText: scorer.playerName)
                            .frame(width: 52, height: 52)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(scorer.playerName)
                                .font(FootballTypography.cardTitle)
                                .foregroundStyle(FootballColors.textPrimary)
                                .lineLimit(1)
                            HStack(spacing: FootballSpacing.sm) {
                                if let crest = scorerTeam(for: scorer) {
                                    RemoteBadgeImage(urlString: crest.logoURL, placeholderText: crest.name, dimension: 22)
                                }
                                Text(scorer.teamName)
                                    .font(FootballTypography.caption)
                                    .foregroundStyle(FootballColors.textSecondary)
                                    .lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Text("\(scorer.goals) G")
                            .font(FootballTypography.cardTitle)
                            .foregroundStyle(FootballColors.textPrimary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
                    .footballCardStyle()
                }
            }
        }
    }

    private func scorerTeam(for scorer: TopScorer) -> Team? {
        let tn = scorer.teamName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tn.isEmpty else { return nil }
        return viewModel.teams.first { team in
            tn.caseInsensitiveCompare(team.name) == .orderedSame
                || team.name.localizedCaseInsensitiveContains(tn)
                || tn.localizedCaseInsensitiveContains(team.name)
        }
    }
}

struct WrapCollection<Item: Identifiable & Hashable, Content: View>: View {
    let items: [Item]
    @Binding var selectedItem: Item?
    let content: (Item) -> Content

    var body: some View {
        FlexibleView(
            data: items,
            spacing: FootballSpacing.sm,
            alignment: .leading
        ) { item in
            Button {
                selectedItem = item
            } label: {
                content(item)
            }
            .buttonStyle(.plain)
        }
    }
}

struct FlexibleView<Data: Collection, Content: View>: View where Data.Element: Hashable {
    let data: Data
    let spacing: CGFloat
    let alignment: HorizontalAlignment
    let content: (Data.Element) -> Content

    @State private var availableWidth: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            generateContent(in: geometry)
        }
        .frame(height: computeHeight())
    }

    private func generateContent(in geometry: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero
        let array = Array(data)
        return ZStack(alignment: Alignment(horizontal: alignment, vertical: .top)) {
            ForEach(array, id: \.self) { item in
                content(item)
                    .padding([.horizontal, .vertical], spacing / 2)
                    .alignmentGuide(.leading) { dimensions in
                        if abs(width - dimensions.width) > geometry.size.width {
                            width = 0
                            height -= dimensions.height
                        }
                        let result = width
                        if item == array.last {
                            width = 0
                        } else {
                            width -= dimensions.width
                        }
                        return result
                    }
                    .alignmentGuide(.top) { _ in
                        let result = height
                        if item == array.last {
                            height = 0
                        }
                        return result
                    }
            }
        }
        .onAppear {
            availableWidth = geometry.size.width
        }
    }

    private func computeHeight() -> CGFloat {
        max(availableWidth > 0 ? 120 : 0, 120)
    }
}

