import Foundation

protocol LeagueRepository {
    func getCountries() async throws -> [Country]
    func getSeasons() async throws -> [Season]
    func getLeagues(country: String?, season: Int?) async throws -> [League]
    func getStandings(leagueID: Int, season: Int) async throws -> [StandingRow]
}

protocol TeamRepository {
    func getTeams(leagueID: Int, season: Int) async throws -> [Team]
    func getTeamProfile(teamID: Int, leagueID: Int, season: Int) async throws -> TeamProfileData
    func getTeamStatistics(teamID: Int, leagueID: Int, season: Int) async throws -> TeamStatistics
    func getPlayerStatistics(teamID: Int, season: Int) async throws -> [PlayerStatistics]
    func getTopScorers(leagueID: Int, season: Int) async throws -> [TopScorer]
}

protocol FixtureRepository {
    func getDashboard(context: AppContextSelection) async throws -> DashboardData
    func getFixtures(leagueID: Int, season: Int, teamID: Int?, date: Date?, status: MatchStatus?) async throws -> [Fixture]
    func getLiveFixtures() async throws -> [Fixture]
    func getMatchDetail(fixtureID: Int) async throws -> MatchDetailData
}

protocol SearchRepository {
    func search(query: String, context: AppContextSelection) async throws -> SearchResults
}

protocol FavoritesRepository {
    func getFavorites() throws -> [FavoriteTeam]
    func isFavorite(teamID: Int) throws -> Bool
    func toggleFavorite(team: Team, leagueID: Int, seasonYear: Int) throws -> [FavoriteTeam]
}

protocol UserSettingsRepository {
    func getSelection() throws -> AppContextSelection
    func saveSelection(_ selection: AppContextSelection) throws
    func getOnboardingCompleted() throws -> Bool
    func setOnboardingCompleted(_ value: Bool) throws
    func getLiveRefreshInterval() throws -> TimeInterval
    func setLiveRefreshInterval(_ value: TimeInterval) throws
    func clearCache() throws
}
