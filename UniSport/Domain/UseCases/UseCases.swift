import Foundation

struct GetHomeDashboardUseCase {
    let repository: FixtureRepository

    func execute(context: AppContextSelection) async throws -> DashboardData {
        try await repository.getDashboard(context: context)
    }
}

struct GetLeaguesUseCase {
    let repository: LeagueRepository

    func execute(country: String?, season: Int?) async throws -> [League] {
        try await repository.getLeagues(country: country, season: season)
    }
}

struct GetTeamsUseCase {
    let repository: TeamRepository

    func execute(leagueID: Int, season: Int) async throws -> [Team] {
        try await repository.getTeams(leagueID: leagueID, season: season)
    }
}

struct GetFixturesUseCase {
    let repository: FixtureRepository

    func execute(leagueID: Int, season: Int, teamID: Int?, date: Date?, status: MatchStatus?) async throws -> [Fixture] {
        try await repository.getFixtures(leagueID: leagueID, season: season, teamID: teamID, date: date, status: status)
    }
}

struct GetLiveFixturesUseCase {
    let repository: FixtureRepository

    func execute() async throws -> [Fixture] {
        try await repository.getLiveFixtures()
    }
}

struct GetStandingsUseCase {
    let repository: LeagueRepository

    func execute(leagueID: Int, season: Int) async throws -> [StandingRow] {
        try await repository.getStandings(leagueID: leagueID, season: season)
    }
}

struct GetMatchDetailUseCase {
    let repository: FixtureRepository

    func execute(fixtureID: Int) async throws -> MatchDetailData {
        try await repository.getMatchDetail(fixtureID: fixtureID)
    }
}

struct GetTeamProfileUseCase {
    let repository: TeamRepository

    func execute(teamID: Int, leagueID: Int, season: Int) async throws -> TeamProfileData {
        try await repository.getTeamProfile(teamID: teamID, leagueID: leagueID, season: season)
    }
}

struct GetTeamStatisticsUseCase {
    let repository: TeamRepository

    func execute(teamID: Int, leagueID: Int, season: Int) async throws -> TeamStatistics {
        try await repository.getTeamStatistics(teamID: teamID, leagueID: leagueID, season: season)
    }
}

struct GetTopScorersUseCase {
    let repository: TeamRepository

    func execute(leagueID: Int, season: Int) async throws -> [TopScorer] {
        try await repository.getTopScorers(leagueID: leagueID, season: season)
    }
}

struct SearchEntitiesUseCase {
    let repository: SearchRepository

    func execute(query: String, context: AppContextSelection) async throws -> SearchResults {
        try await repository.search(query: query, context: context)
    }
}

struct ToggleFavoriteUseCase {
    let repository: FavoritesRepository

    func execute(team: Team, leagueID: Int, seasonYear: Int) throws -> [FavoriteTeam] {
        try repository.toggleFavorite(team: team, leagueID: leagueID, seasonYear: seasonYear)
    }
}
