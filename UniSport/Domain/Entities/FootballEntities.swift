import Foundation

struct Country: Identifiable, Codable, Hashable {
    let id: Int
    let name: String
    let code: String
    let flagURL: String?
}

struct Season: Identifiable, Codable, Hashable {
    static let appKickoffYear = 2025
    static var appKickoffDisplay: String { "\(appKickoffYear)/\(appKickoffYear + 1)" }

    let id: Int
    let year: Int
    let isCurrent: Bool

    var slashDisplay: String {
        "\(year)/\(year + 1)"
    }
}

struct League: Identifiable, Codable, Hashable {
    let id: Int
    let name: String
    let type: String
    let logoURL: String?
    let country: Country
    let currentSeason: Season
}

struct Team: Identifiable, Codable, Hashable {
    let id: Int
    let name: String
    let code: String?
    let logoURL: String?
    let country: String
    let founded: Int?
    let venueName: String?
}

struct Score: Codable, Hashable {
    let home: Int?
    let away: Int?
    let halftimeHome: Int?
    let halftimeAway: Int?
}

struct Fixture: Identifiable, Codable, Hashable {
    let id: Int
    let league: League
    let season: Season
    let round: String
    let date: Date
    let venue: String?
    let status: MatchStatus
    let statusDisplay: String
    let referee: String?
    let homeTeam: Team
    let awayTeam: Team
    let score: Score
    let elapsed: Int?

    var isUpcomingMatch: Bool {
        if status == .upcoming {
            return true
        }
        let now = Date()
        return date > now && status != .finished && status != .live && status != .postponed
    }
}

struct StandingRow: Identifiable, Codable, Hashable {
    let id: Int
    let rank: Int
    let team: Team
    let played: Int
    let won: Int
    let drawn: Int
    let lost: Int
    let goalsFor: Int
    let goalsAgainst: Int
    let goalDifference: Int
    let points: Int
    let form: [FormResult]
}

struct MatchEvent: Identifiable, Codable, Hashable {
    let id: UUID
    let minute: Int
    let type: String
    let detail: String
    let teamName: String
    let playerName: String?
    let assistName: String?
}

struct LineupPlayer: Identifiable, Codable, Hashable {
    let id: Int
    let name: String
    let number: Int?
    let position: String
}

struct Lineup: Identifiable, Codable, Hashable {
    let id: UUID
    let team: Team
    let formation: String
    let coach: String
    let startXI: [LineupPlayer]
    let substitutes: [LineupPlayer]
}

struct TeamStatistic: Identifiable, Codable, Hashable {
    let id: UUID
    let title: String
    let homeValue: Double
    let awayValue: Double
    let suffix: String
}

struct TeamStatistics: Identifiable, Codable, Hashable {
    let id: UUID
    let team: Team
    let wins: Int
    let draws: Int
    let losses: Int
    let goalsFor: Int
    let goalsAgainst: Int
    let cleanSheets: Int
    let averagePossession: Double
    let averageShots: Double
    let recentForm: [FormResult]
}

struct PlayerStatistics: Identifiable, Codable, Hashable {
    let id: Int
    let playerName: String
    let teamName: String
    let position: String
    let photoURL: String?
    let minutes: Int
    let goals: Int
    let assists: Int
    let yellowCards: Int
    let redCards: Int
    let rating: Double?
}

struct TopScorer: Identifiable, Codable, Hashable {
    let id: Int
    let playerName: String
    let teamName: String
    let photoURL: String?
    let goals: Int
    let assists: Int
    let minutes: Int
}

struct FavoriteTeam: Identifiable, Codable, Hashable {
    let id: Int
    let team: Team
    let leagueID: Int
    let seasonYear: Int
    let pinned: Bool
}

struct CachedAPIResponse<T: Codable>: Codable {
    let cacheKey: String
    let payload: T
    let expiryDate: Date
    let source: String
    let isStale: Bool
}

struct DashboardData: Codable, Hashable {
    let todayFixtures: [Fixture]
    let liveFixtures: [Fixture]
    let upcomingFixtures: [Fixture]
    let finishedFixtures: [Fixture]
    let recommendedLeagues: [League]
    let standingsPreview: [StandingRow]
    let favoriteTeams: [FavoriteTeam]
    let featuredStats: [TeamStatistic]
}

struct MatchDetailData: Codable, Hashable {
    let fixture: Fixture
    let events: [MatchEvent]
    let statistics: [TeamStatistic]
    let lineups: [Lineup]
    let relatedFixtures: [Fixture]
}

struct TeamProfileData: Codable, Hashable {
    let team: Team
    let league: League
    let recentForm: [FormResult]
    let upcomingFixtures: [Fixture]
    let statistics: TeamStatistics
    let squad: [PlayerStatistics]
}

struct SearchResults: Codable, Hashable {
    let leagues: [League]
    let teams: [Team]
    let fixtures: [Fixture]
}
