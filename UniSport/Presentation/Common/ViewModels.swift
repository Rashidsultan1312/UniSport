import Foundation
import SwiftUI
import Combine

@MainActor
final class LaunchViewModel: ObservableObject {
    @Published var countries: [Country] = []
    @Published var seasons: [Season] = []
    @Published var leagues: [League] = []
    @Published var teams: [Team] = []
    @Published var dashboardState: DataState<DashboardData> = .idle
    @Published var fixturesState: DataState<[Fixture]> = .idle
    @Published var standingsState: DataState<[StandingRow]> = .idle
    @Published var liveState: DataState<[Fixture]> = .idle
    @Published var matchDetailState: DataState<MatchDetailData> = .idle
    @Published var teamProfileState: DataState<TeamProfileData> = .idle
    @Published var topScorersState: DataState<[TopScorer]> = .idle
    @Published var searchState: DataState<SearchResults> = .idle
    @Published var favorites: [FavoriteTeam] = []

    private let getDashboard: GetHomeDashboardUseCase
    private let getLeagues: GetLeaguesUseCase
    private let getTeams: GetTeamsUseCase
    private let getFixtures: GetFixturesUseCase
    private let getLiveFixtures: GetLiveFixturesUseCase
    private let getStandings: GetStandingsUseCase
    private let getMatchDetail: GetMatchDetailUseCase
    private let getTeamProfile: GetTeamProfileUseCase
    private let getTopScorers: GetTopScorersUseCase
    private let searchUseCase: SearchEntitiesUseCase
    private let toggleFavorite: ToggleFavoriteUseCase
    private let leagueRepository: LeagueRepository
    private let settingsRepository: UserSettingsRepository

    init(container: AppContainer) {
        self.getDashboard = GetHomeDashboardUseCase(repository: container.fixtureRepository)
        self.getLeagues = GetLeaguesUseCase(repository: container.leagueRepository)
        self.getTeams = GetTeamsUseCase(repository: container.teamRepository)
        self.getFixtures = GetFixturesUseCase(repository: container.fixtureRepository)
        self.getLiveFixtures = GetLiveFixturesUseCase(repository: container.fixtureRepository)
        self.getStandings = GetStandingsUseCase(repository: container.leagueRepository)
        self.getMatchDetail = GetMatchDetailUseCase(repository: container.fixtureRepository)
        self.getTeamProfile = GetTeamProfileUseCase(repository: container.teamRepository)
        self.getTopScorers = GetTopScorersUseCase(repository: container.teamRepository)
        self.searchUseCase = SearchEntitiesUseCase(repository: container.searchRepository)
        self.toggleFavorite = ToggleFavoriteUseCase(repository: container.favoritesRepository)
        self.leagueRepository = container.leagueRepository
        self.settingsRepository = container.settingsRepository
        self.favorites = (try? container.favoritesRepository.getFavorites()) ?? []
    }

    func loadFilters(selection: AppContextSelection) async {
        do {
            countries = try await leagueRepository.getCountries()
        } catch is CancellationError {
            return
        } catch {
            UniSportLog.vm("loadFilters countries \(error)")
        }
        do {
            seasons = try await leagueRepository.getSeasons()
        } catch {
            UniSportLog.vm("loadFilters seasons \(error)")
        }
        do {
            leagues = try await getLeagues.execute(country: selection.country?.name, season: selection.season?.year)
        } catch is CancellationError {
            return
        } catch {
            UniSportLog.vm("loadFilters leagues \(error)")
        }
        guard let leagueID = selection.league?.id ?? leagues.first?.id,
              let season = selection.season?.year ?? seasons.first?.year else {
            return
        }
        do {
            teams = try await getTeams.execute(leagueID: leagueID, season: season)
        } catch is CancellationError {
            return
        } catch {
            UniSportLog.vm("loadFilters teams \(error)")
        }
    }

    func refreshHome(selection: AppContextSelection) async {
        dashboardState = .loading
        do {
            let data = try await getDashboard.execute(context: selection)
            dashboardState = .success(data)
            favorites = data.favoriteTeams
        } catch {
            UniSportLog.vm("refreshHome first try \(error)")
            await loadFilters(selection: selection)
            let fallbackSelection = AppContextSelection(
                country: selection.country ?? countries.first,
                season: selection.season ?? seasons.first,
                league: selection.league ?? leagues.first,
                team: selection.team ?? teams.first
            )
            do {
                let data = try await getDashboard.execute(context: fallbackSelection)
                dashboardState = .success(data)
                favorites = data.favoriteTeams
            } catch {
                UniSportLog.vm("refreshHome fallback \(error) fallbackSelection league=\(String(describing: fallbackSelection.league?.id))")
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                dashboardState = .failure("The dashboard could not be loaded.")
            }
        }
    }

    func refreshFixtures(selection: AppContextSelection, status: MatchStatus? = nil) async {
        fixturesState = .loading
        guard let leagueID = selection.league?.id ?? leagues.first?.id, let season = selection.season?.year ?? seasons.first?.year else {
            fixturesState = .empty("Select a league and season to view fixtures.")
            return
        }
        do {
            let value = try await getFixtures.execute(leagueID: leagueID, season: season, teamID: selection.team?.id, date: nil, status: status)
            fixturesState = value.isEmpty ? .empty("No fixtures match the current filters.") : .success(value)
        } catch {
            UniSportLog.vm("refreshFixtures \(error)")
            fixturesState = .failure("Fixtures are unavailable right now.")
        }
    }

    func refreshStandings(selection: AppContextSelection) async {
        standingsState = .loading
        guard let leagueID = selection.league?.id ?? leagues.first?.id, let season = selection.season?.year ?? seasons.first?.year else {
            standingsState = .empty("Select a league and season to view standings.")
            return
        }
        do {
            let value = try await getStandings.execute(leagueID: leagueID, season: season)
            standingsState = value.isEmpty ? .empty("Standings are unavailable for this season.") : .success(value)
        } catch {
            UniSportLog.vm("refreshStandings \(error)")
            standingsState = .failure("Standings could not be loaded.")
        }
    }

    func refreshLive() async {
        liveState = .loading
        do {
            let value = try await getLiveFixtures.execute()
            liveState = value.isEmpty ? .empty("No live matches right now.") : .success(value)
        } catch {
            UniSportLog.vm("refreshLive \(error)")
            liveState = .failure("Live matches are unavailable.")
        }
    }

    func loadMatchDetail(fixtureID: Int) async {
        matchDetailState = .loading
        do {
            let value = try await getMatchDetail.execute(fixtureID: fixtureID)
            matchDetailState = .success(value)
        } catch {
            UniSportLog.vm("loadMatchDetail \(fixtureID) \(error)")
            matchDetailState = .failure("Match detail could not be loaded.")
        }
    }

    func loadTeamProfile(teamID: Int, leagueID: Int, season: Int) async {
        teamProfileState = .loading
        do {
            let value = try await getTeamProfile.execute(teamID: teamID, leagueID: leagueID, season: season)
            teamProfileState = .success(value)
        } catch {
            UniSportLog.vm("loadTeamProfile team=\(teamID) \(error)")
            teamProfileState = .failure("Team profile is unavailable.")
        }
    }

    func loadTopScorers(leagueID: Int, season: Int) async {
        topScorersState = .loading
        do {
            let value = try await getTopScorers.execute(leagueID: leagueID, season: season)
            topScorersState = value.isEmpty ? .empty("Top scorers are unavailable.") : .success(value)
        } catch {
            UniSportLog.vm("loadTopScorers \(error)")
            topScorersState = .failure("Top scorers could not be loaded.")
        }
    }

    func search(_ query: String, selection: AppContextSelection) async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchState = .empty("Start typing to search teams, leagues, or fixtures.")
            return
        }
        searchState = .loading
        do {
            let value = try await searchUseCase.execute(query: query, context: selection)
            if value.leagues.isEmpty && value.teams.isEmpty && value.fixtures.isEmpty {
                searchState = .empty("No results match your search.")
            } else {
                searchState = .success(value)
            }
        } catch {
            UniSportLog.vm("search \(error)")
            searchState = .failure("Search is unavailable right now.")
        }
    }

    func toggleFavorite(team: Team, leagueID: Int, seasonYear: Int) {
        favorites = (try? toggleFavorite.execute(team: team, leagueID: leagueID, seasonYear: seasonYear)) ?? favorites
    }

    func saveLiveRefreshInterval(_ interval: TimeInterval) {
        try? settingsRepository.setLiveRefreshInterval(interval)
    }

    func clearCache() -> String {
        do {
            try settingsRepository.clearCache()
            return "Cached data cleared."
        } catch {
            return "Cached data could not be cleared."
        }
    }
}
