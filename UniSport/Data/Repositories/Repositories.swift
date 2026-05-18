import Foundation

final class AppSettingsStore: UserSettingsRepository {
    private enum Keys {
        static let selection = "app.selection"
        static let onboarding = "app.onboarding"
        static let liveRefreshInterval = "app.liveRefreshInterval"
    }

    private let store: KeyValueStore
    private let diskCache: DiskCache

    init(store: KeyValueStore, diskCache: DiskCache) {
        self.store = store
        self.diskCache = diskCache
    }

    func getSelection() throws -> AppContextSelection {
        try store.load(AppContextSelection.self, forKey: Keys.selection) ?? .empty
    }

    func saveSelection(_ selection: AppContextSelection) throws {
        try store.save(selection, forKey: Keys.selection)
    }

    func getOnboardingCompleted() throws -> Bool {
        store.loadBool(forKey: Keys.onboarding)
    }

    func setOnboardingCompleted(_ value: Bool) throws {
        store.saveBool(value, forKey: Keys.onboarding)
    }

    func getLiveRefreshInterval() throws -> TimeInterval {
        let value = store.loadDouble(forKey: Keys.liveRefreshInterval)
        return value == 0 ? 20 : value
    }

    func setLiveRefreshInterval(_ value: TimeInterval) throws {
        store.saveDouble(value, forKey: Keys.liveRefreshInterval)
    }

    func clearCache() throws {
        MemoryCache.shared.clear()
        try diskCache.clear()
    }
}

final class DefaultFavoritesRepository: FavoritesRepository {
    private enum Keys {
        static let favorites = "favorites.teams"
    }

    private let store: KeyValueStore

    init(store: KeyValueStore) {
        self.store = store
    }

    func getFavorites() throws -> [FavoriteTeam] {
        try store.load([FavoriteTeam].self, forKey: Keys.favorites) ?? []
    }

    func isFavorite(teamID: Int) throws -> Bool {
        try getFavorites().contains(where: { $0.team.id == teamID })
    }

    func toggleFavorite(team: Team, leagueID: Int, seasonYear: Int) throws -> [FavoriteTeam] {
        var favorites = try getFavorites()
        if let index = favorites.firstIndex(where: { $0.team.id == team.id }) {
            favorites.remove(at: index)
        } else {
            favorites.append(FavoriteTeam(id: team.id, team: team, leagueID: leagueID, seasonYear: seasonYear, pinned: favorites.isEmpty))
        }
        try store.save(favorites, forKey: Keys.favorites)
        return favorites
    }
}

final class APIFootballRepository: LeagueRepository, TeamRepository, FixtureRepository, SearchRepository {
    private let client: HTTPClient
    private let favoritesRepository: FavoritesRepository
    private let settingsRepository: UserSettingsRepository
    private let cache: DiskCache
    private let config: APIConfig
    private let cachePrefix = "thesportsdb.v1"
    private var defaultSeasonStart: Int { Season.appKickoffYear }

    init(
        client: HTTPClient,
        favoritesRepository: FavoritesRepository,
        settingsRepository: UserSettingsRepository,
        cache: DiskCache,
        config: APIConfig
    ) {
        self.client = client
        self.favoritesRepository = favoritesRepository
        self.settingsRepository = settingsRepository
        self.cache = cache
        self.config = config
    }

    func getCountries() async throws -> [Country] {
        let key = "\(cachePrefix).countries"
        if let cached = try cache.load([Country].self, for: key) {
            return cached.value
        }
        let response = try await client.send(APIFootballEndpoint.countries.request(apiKey: config.apiKey), as: CountriesResponse.self)
        let countries = (response.countries ?? []).enumerated().map { index, item in
            Country(id: index + 1, name: item.name, code: item.code ?? "", flagURL: item.flagURL)
        }
        try cache.save(countries, for: key, expiryDate: Date().addingTimeInterval(CacheTTL.countriesAndLeagues))
        return countries
    }

    func getSeasons() async throws -> [Season] {
        [Season(id: defaultSeasonStart, year: defaultSeasonStart, isCurrent: true)]
    }

    func getLeagues(country: String?, season: Int?) async throws -> [League] {
        _ = country
        let targetSeason = normalizedSeason(season)
        let expected = CuratedLeague.orderedIDs.count
        let fetchKey = "\(cachePrefix).curatedLeagues.v4.\(targetSeason).all"
        let allLeagues: [League]
        if let cached = try cache.load([League].self, for: fetchKey), cached.value.count == expected {
            allLeagues = cached.value
        } else {
            var built: [League] = []
            for (idx, lid) in CuratedLeague.orderedIDs.enumerated() {
                if idx > 0 {
                    try await Task.sleep(nanoseconds: 120_000_000)
                }
                let request = APIFootballEndpoint.leagueDetails(leagueID: lid).request(apiKey: config.apiKey)
                guard let response = try? await client.send(request, as: LookupLeaguesResponse.self) else { continue }
                guard let dto = response.leagues?.first, let lidInt = Int(dto.idLeague ?? "") else { continue }
                let countryName = dto.strCountry ?? ""
                built.append(
                    League(
                        id: lidInt,
                        name: dto.strLeague,
                        type: dto.strSport,
                        logoURL: dto.strBadge,
                        country: Country(id: countryID(from: countryName), name: countryName, code: "", flagURL: nil),
                        currentSeason: Season(id: targetSeason, year: targetSeason, isCurrent: idx == 0)
                    )
                )
            }
            allLeagues = built
            if allLeagues.count == expected {
                try cache.save(allLeagues, for: fetchKey, expiryDate: Date().addingTimeInterval(CacheTTL.countriesAndLeagues))
            } else {
                UniSportLog.repo("getLeagues partial fetch \(allLeagues.count)/\(expected), not caching")
            }
        }
        UniSportLog.repo("getLeagues season=\(targetSeason) count=\(allLeagues.count) (curated, country param ignored)")
        return allLeagues
    }

    func getStandings(leagueID: Int, season: Int) async throws -> [StandingRow] {
        let season = normalizedSeason(season)
        guard CuratedLeague.allowedIDSet.contains(leagueID) else { return [] }
        let key = "\(cachePrefix).standings.\(leagueID).\(season)"
        if let cached = try cache.load([StandingRow].self, for: key) {
            return cached.value
        }
        let seasonCandidates = seasonQueryCandidates(for: season)
        var tableRows: [StandingDTO] = []
        for seasonValue in seasonCandidates {
            let request = APIFootballEndpoint.standingsRaw(leagueID: leagueID, seasonQuery: seasonValue).request(apiKey: config.apiKey)
            guard let response = try? await client.send(request, as: StandingsResponse.self) else { continue }
            if let rows = response.table, !rows.isEmpty {
                tableRows = rows
                break
            }
        }
        if tableRows.isEmpty {
            let fallbackRequest = APIFootballEndpoint.standingsRaw(leagueID: leagueID, seasonQuery: nil).request(apiKey: config.apiKey)
            if let fallbackResponse = try? await client.send(fallbackRequest, as: StandingsResponse.self) {
                tableRows = fallbackResponse.table ?? []
            }
        }
        let teams = try await getTeams(leagueID: leagueID, season: season)
        let standings = tableRows.enumerated().map { index, row in
            let team = teams.first(where: { $0.name == row.teamName }) ?? Team(
                id: index + 1,
                name: row.teamName,
                code: nil,
                logoURL: row.teamBadge,
                country: "",
                founded: nil,
                venueName: nil
            )
            return StandingRow(
                id: row.teamID ?? index + 1,
                rank: row.intRank ?? (index + 1),
                team: team,
                played: row.intPlayed ?? 0,
                won: row.intWin ?? 0,
                drawn: row.intDraw ?? 0,
                lost: row.intLoss ?? 0,
                goalsFor: row.intGoalsFor ?? 0,
                goalsAgainst: row.intGoalsAgainst ?? 0,
                goalDifference: row.intGoalDifference ?? 0,
                points: row.intPoints ?? 0,
                form: parseForm(row.strForm)
            )
        }
        try cache.save(standings, for: key, expiryDate: Date().addingTimeInterval(CacheTTL.standings))
        return standings
    }

    func getTeams(leagueID: Int, season: Int) async throws -> [Team] {
        guard CuratedLeague.allowedIDSet.contains(leagueID) else { return [] }
        let season = normalizedSeason(season)
        let key = "\(cachePrefix).teams.\(leagueID).\(season)"
        if let cached = try cache.load([Team].self, for: key) {
            return cached.value
        }
        let request = APIFootballEndpoint.teams(leagueID: leagueID, season: season).request(apiKey: config.apiKey)
        guard let response = try? await client.send(request, as: TeamsResponse.self) else { return [] }
        let teams = (response.teams ?? []).compactMap(mapTeam)
        try cache.save(teams, for: key, expiryDate: Date().addingTimeInterval(CacheTTL.teams))
        return teams
    }

    func getTeamProfile(teamID: Int, leagueID: Int, season: Int) async throws -> TeamProfileData {
        let teams = try await getTeams(leagueID: leagueID, season: season)
        guard let team = teams.first(where: { $0.id == teamID }) else { throw NetworkError.noData }
        let leagues = try await getLeagues(country: nil, season: season)
        guard let league = leagues.first(where: { $0.id == leagueID }) else { throw NetworkError.noData }
        let fixtures = try await getFixtures(leagueID: leagueID, season: season, teamID: teamID, date: nil, status: .upcoming)
        let statistics = try await getTeamStatistics(teamID: teamID, leagueID: leagueID, season: season)
        let players = try await getPlayerStatistics(teamID: teamID, season: season)
        return TeamProfileData(
            team: team,
            league: league,
            recentForm: statistics.recentForm,
            upcomingFixtures: Array(fixtures.prefix(5)),
            statistics: statistics,
            squad: players
        )
    }

    func getTeamStatistics(teamID: Int, leagueID: Int, season: Int) async throws -> TeamStatistics {
        let standings = try await getStandings(leagueID: leagueID, season: season)
        guard let row = standings.first(where: { $0.team.id == teamID }) else {
            guard let team = try await getTeams(leagueID: leagueID, season: season).first(where: { $0.id == teamID }) else {
                throw NetworkError.noData
            }
            return TeamStatistics(id: UUID(), team: team, wins: 0, draws: 0, losses: 0, goalsFor: 0, goalsAgainst: 0, cleanSheets: 0, averagePossession: 0, averageShots: 0, recentForm: [])
        }
        let played = max(1, row.played)
        return TeamStatistics(
            id: UUID(),
            team: row.team,
            wins: row.won,
            draws: row.drawn,
            losses: row.lost,
            goalsFor: row.goalsFor,
            goalsAgainst: row.goalsAgainst,
            cleanSheets: 0,
            averagePossession: 0,
            averageShots: Double(row.goalsFor) / Double(played),
            recentForm: row.form
        )
    }

    func getPlayerStatistics(teamID: Int, season: Int) async throws -> [PlayerStatistics] {
        let response = try await client.send(APIFootballEndpoint.players(teamID: teamID, season: season).request(apiKey: config.apiKey), as: PlayersResponse.self)
        return (response.player ?? []).compactMap { player in
            guard let id = Int(player.idPlayer ?? "") else { return nil }
            return PlayerStatistics(
                id: id,
                playerName: player.strPlayer ?? "Unknown",
                teamName: player.strTeam ?? "",
                position: player.strPosition ?? "Unknown",
                photoURL: player.strCutout ?? player.strRender ?? player.strThumb,
                minutes: 0,
                goals: Int(player.strGoals ?? "") ?? 0,
                assists: Int(player.strAssists ?? "") ?? 0,
                yellowCards: Int(player.strYellowCards ?? "") ?? 0,
                redCards: Int(player.strRedCards ?? "") ?? 0,
                rating: nil
            )
        }
    }

    func getTopScorers(leagueID: Int, season: Int) async throws -> [TopScorer] {
        guard CuratedLeague.allowedIDSet.contains(leagueID) else { return [] }
        let season = normalizedSeason(season)
        let key = "\(cachePrefix).topscorers.v2.\(leagueID).\(season)"
        if let cached = try cache.load([TopScorer].self, for: key) {
            return cached.value
        }
        let request = APIFootballEndpoint.topScorers(leagueID: leagueID, season: season).request(apiKey: config.apiKey)
        let response = try await client.send(request, as: TopScorersResponse.self)
        let scorers = (response.topscorers ?? []).compactMap { item -> TopScorer? in
            guard let id = Int(item.idPlayer ?? "") else { return nil }
            return TopScorer(
                id: id,
                playerName: item.strPlayer ?? "Unknown",
                teamName: item.strTeam ?? "",
                photoURL: item.strCutout ?? item.strRender ?? item.strThumb,
                goals: Int(item.intGoals ?? "") ?? 0,
                assists: Int(item.intAssists ?? "") ?? 0,
                minutes: Int(item.intMinutes ?? "") ?? 0
            )
        }
        try cache.save(scorers, for: key, expiryDate: Date().addingTimeInterval(CacheTTL.topScorers))
        return scorers
    }

    func getDashboard(context: AppContextSelection) async throws -> DashboardData {
        let season = normalizedSeason(context.season?.year)
        let leagues = try await getLeagues(country: context.country?.name, season: season)

        let resolvedLeagueID: Int
        if let selected = context.league?.id, CuratedLeague.allowedIDSet.contains(selected), leagues.contains(where: { $0.id == selected }) {
            resolvedLeagueID = selected
        } else if let preferred = leagues.first?.id {
            resolvedLeagueID = preferred
        } else if let fallback = CuratedLeague.orderedIDs.first {
            resolvedLeagueID = fallback
        } else {
            resolvedLeagueID = 4328
        }

        let favorites = (try? favoritesRepository.getFavorites()) ?? []
        let fixtures = (try? await getFixtures(leagueID: resolvedLeagueID, season: season, teamID: nil, date: nil, status: nil)) ?? []
        let featuredStats = makeFeaturedStats(from: fixtures)
        let liveFixtures = ((try? await getLiveFixtures()) ?? []).filter { CuratedLeague.allowedIDSet.contains($0.league.id) }
        let standings = (try? await getStandings(leagueID: resolvedLeagueID, season: season)) ?? []
        let upcoming = fixtures.filter(\.isUpcomingMatch).sorted { $0.date < $1.date }
        let finished = fixtures.filter { $0.status == .finished }.sorted { $0.date > $1.date }
        UniSportLog.repo("getDashboard season=\(season) league=\(resolvedLeagueID) leagues=\(leagues.count) fixtures=\(fixtures.count) live=\(liveFixtures.count) standingsPreview=\(standings.count)")
        return DashboardData(
            todayFixtures: fixtures.filter { Calendar.current.isDateInToday($0.date) },
            liveFixtures: liveFixtures,
            upcomingFixtures: upcoming,
            finishedFixtures: finished,
            recommendedLeagues: leagues,
            standingsPreview: standings,
            favoriteTeams: favorites,
            featuredStats: featuredStats
        )
    }

    func getFixtures(leagueID: Int, season: Int, teamID: Int?, date: Date?, status: MatchStatus?) async throws -> [Fixture] {
        guard CuratedLeague.allowedIDSet.contains(leagueID) else { return [] }
        let season = normalizedSeason(season)
        let key = "\(cachePrefix).fixtures.v3.\(leagueID).\(season)"
        let fixtures: [Fixture]
        if let cached = try cache.load([Fixture].self, for: key), !cached.isStale {
            fixtures = cached.value
        } else {
            let leagues = try await getLeagues(country: nil, season: season)
            let league = leagues.first(where: { $0.id == leagueID }) ?? League(
                id: leagueID,
                name: "",
                type: "Soccer",
                logoURL: nil,
                country: Country(id: 0, name: "", code: "", flagURL: nil),
                currentSeason: Season(id: season, year: season, isCurrent: false)
            )
            let seasonCandidates = seasonQueryCandidates(for: season)
            var rawEvents: [EventDTO] = []
            for seasonValue in seasonCandidates {
                let request = APIFootballEndpoint.fixturesRaw(leagueID: leagueID, seasonQuery: seasonValue).request(apiKey: config.apiKey)
                let response = try await client.send(request, as: FixturesResponse.self)
                if let events = response.events, !events.isEmpty {
                    rawEvents = events
                    break
                }
            }
            let nextLeagueRequest = APIFootballEndpoint.nextLeagueFixtures(leagueID: leagueID).request(apiKey: config.apiKey)
            if let nextResponse = try? await client.send(nextLeagueRequest, as: FixturesResponse.self),
               let upcoming = nextResponse.events, !upcoming.isEmpty {
                rawEvents = mergeDedupedEvents(seasonEvents: rawEvents, extra: upcoming)
            }
            if rawEvents.isEmpty {
                UniSportLog.repo("getFixtures mapped 0 raw events leagueID=\(leagueID) season=\(season) candidates=\(seasonCandidates)")
            }
            fixtures = rawEvents.compactMap { mapFixture($0, fallbackLeague: league, seasonYear: season) }
            try cache.save(fixtures, for: key, expiryDate: Date().addingTimeInterval(CacheTTL.fixtures))
        }
        return fixtures.filter { fixture in
            let teamMatch = teamID == nil || fixture.homeTeam.id == teamID || fixture.awayTeam.id == teamID
            let statusMatch: Bool
            if let status {
                if status == .upcoming {
                    statusMatch = fixture.isUpcomingMatch
                } else {
                    statusMatch = fixture.status == status
                }
            } else {
                statusMatch = true
            }
            let dateMatch = date.map { Calendar.current.isDate(fixture.date, inSameDayAs: $0) } ?? true
            return teamMatch && statusMatch && dateMatch
        }
    }

    func getLiveFixtures() async throws -> [Fixture] {
        let response = try await client.send(APIFootballEndpoint.liveFixtures.request(apiKey: config.apiKey), as: FixturesResponse.self)
        let seasonHint = normalizedSeason(nil)
        return (response.events ?? []).compactMap { mapFixture($0, fallbackLeague: nil, seasonYear: seasonHint) }
            .filter { CuratedLeague.allowedIDSet.contains($0.league.id) && $0.status == .live }
    }

    func getMatchDetail(fixtureID: Int) async throws -> MatchDetailData {
        let eventResponse = try await client.send(APIFootballEndpoint.fixtureByID(fixtureID: fixtureID).request(apiKey: config.apiKey), as: FixturesResponse.self)
        guard let rawFixture = eventResponse.events?.first,
              let fixture = mapFixture(rawFixture, fallbackLeague: nil, seasonYear: normalizedSeason(nil))
        else { throw NetworkError.noData }
        guard CuratedLeague.allowedIDSet.contains(fixture.league.id) else { throw NetworkError.noData }

        let timelineResponse = try await client.send(APIFootballEndpoint.fixtureEvents(fixtureID: fixtureID).request(apiKey: config.apiKey), as: TimelineResponse.self)
        let statsResponse = try await client.send(APIFootballEndpoint.fixtureStatistics(fixtureID: fixtureID).request(apiKey: config.apiKey), as: EventStatisticsResponse.self)
        let lineupResponse = try await client.send(APIFootballEndpoint.fixtureLineups(fixtureID: fixtureID).request(apiKey: config.apiKey), as: EventLineupsResponse.self)

        let relatedFixtures = try await getFixtures(
            leagueID: fixture.league.id,
            season: fixture.season.year,
            teamID: nil,
            date: nil,
            status: nil
        ).filter { $0.id != fixtureID }

        return MatchDetailData(
            fixture: fixture,
            events: (timelineResponse.timeline ?? []).map {
                MatchEvent(
                    id: UUID(),
                    minute: Int($0.intTime ?? "") ?? 0,
                    type: $0.strTimeline ?? "",
                    detail: $0.strTimelineDetail ?? "",
                    teamName: $0.strTeam ?? "",
                    playerName: $0.strPlayer,
                    assistName: $0.strAssist
                )
            },
            statistics: (statsResponse.statistics ?? []).map {
                TeamStatistic(
                    id: UUID(),
                    title: $0.strStat ?? "",
                    homeValue: Double($0.strHome ?? "") ?? 0,
                    awayValue: Double($0.strAway ?? "") ?? 0,
                    suffix: ""
                )
            },
            lineups: (lineupResponse.lineup ?? []).map { item in
                let team = Team(
                    id: Int(item.idTeam ?? "") ?? 0,
                    name: item.strTeam ?? "",
                    code: nil,
                    logoURL: item.strTeamBadge,
                    country: "",
                    founded: nil,
                    venueName: nil
                )
                return Lineup(
                    id: UUID(),
                    team: team,
                    formation: item.strFormation ?? "",
                    coach: item.strCoach ?? "",
                    startXI: [],
                    substitutes: []
                )
            },
            relatedFixtures: Array(relatedFixtures.prefix(10))
        )
    }

    func search(query: String, context: AppContextSelection) async throws -> SearchResults {
        let normalizedTeams = query.replacingOccurrences(of: " ", with: "_")
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)

        let teamsResponse = try await client.send(APIFootballEndpoint.searchTeams(query: normalizedTeams).request(apiKey: config.apiKey), as: TeamsResponse.self)
        let eventsResponse = try await client.send(APIFootballEndpoint.searchEvents(query: normalizedTeams).request(apiKey: config.apiKey), as: FixturesResponse.self)

        let seasonYear = normalizedSeason(context.season?.year)
        let allowed = CuratedLeague.allowedIDSet
        let curated = try await getLeagues(country: nil, season: seasonYear)
        let leagues = needle.isEmpty
            ? curated
            : curated.filter {
                $0.name.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
                    || $0.country.name.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
            }
        let teams = (teamsResponse.teams ?? []).filter { dto in
            guard let lid = Int(dto.idLeague ?? "") else { return false }
            return allowed.contains(lid)
        }.compactMap(mapTeam)
        let fixtures = (eventsResponse.events ?? []).compactMap { mapFixture($0, fallbackLeague: context.league, seasonYear: seasonYear) }
            .filter { allowed.contains($0.league.id) }
        return SearchResults(leagues: leagues, teams: teams, fixtures: fixtures)
    }

    private func makeFeaturedStats(from fixtures: [Fixture]) -> [TeamStatistic] {
        let played = fixtures.filter { $0.status == .finished || $0.status == .live }
        let totalGoals = played.reduce(0) { $0 + ($1.score.home ?? 0) + ($1.score.away ?? 0) }
        let avgGoals = played.isEmpty ? 0 : Double(totalGoals) / Double(played.count)
        return [
            TeamStatistic(id: UUID(), title: "Matches", homeValue: Double(played.count), awayValue: Double(fixtures.count), suffix: ""),
            TeamStatistic(id: UUID(), title: "Avg Goals", homeValue: avgGoals, awayValue: 0, suffix: ""),
            TeamStatistic(id: UUID(), title: "Live", homeValue: Double(fixtures.filter { $0.status == .live }.count), awayValue: 0, suffix: "")
        ]
    }

    private func mergeDedupedEvents(seasonEvents: [EventDTO], extra: [EventDTO]) -> [EventDTO] {
        var seen = Set<String>()
        var out: [EventDTO] = []
        for e in seasonEvents {
            guard let id = e.idEvent else { continue }
            if seen.insert(id).inserted {
                out.append(e)
            }
        }
        for e in extra {
            guard let id = e.idEvent else { continue }
            if seen.insert(id).inserted {
                out.append(e)
            }
        }
        return out
    }

    private func mapFixture(_ raw: EventDTO, fallbackLeague: League?, seasonYear: Int) -> Fixture? {
        guard
            let idString = raw.idEvent,
            let id = Int(idString),
            let date = parseDate(raw.dateEvent) ?? parseDate(raw.strTimestamp)
        else { return nil }
        let league = fallbackLeague ?? League(
            id: Int(raw.idLeague ?? "") ?? 0,
            name: raw.strLeague ?? "",
            type: "Soccer",
            logoURL: nil,
            country: Country(id: 0, name: raw.strCountry ?? "", code: "", flagURL: nil),
            currentSeason: Season(id: seasonYear, year: seasonYear, isCurrent: false)
        )
        let homeTeam = Team(
            id: Int(raw.idHomeTeam ?? "") ?? 0,
            name: raw.strHomeTeam ?? "",
            code: nil,
            logoURL: raw.strHomeTeamBadge,
            country: league.country.name,
            founded: nil,
            venueName: nil
        )
        let awayTeam = Team(
            id: Int(raw.idAwayTeam ?? "") ?? 0,
            name: raw.strAwayTeam ?? "",
            code: nil,
            logoURL: raw.strAwayTeamBadge,
            country: league.country.name,
            founded: nil,
            venueName: nil
        )
        let status = mapStatus(raw.strStatus)
        return Fixture(
            id: id,
            league: league,
            season: Season(id: seasonYear, year: seasonYear, isCurrent: false),
            round: raw.intRound ?? "",
            date: date,
            venue: raw.strVenue,
            status: status,
            statusDisplay: raw.strStatus ?? "",
            referee: raw.strReferee,
            homeTeam: homeTeam,
            awayTeam: awayTeam,
            score: Score(
                home: Int(raw.intHomeScore ?? ""),
                away: Int(raw.intAwayScore ?? ""),
                halftimeHome: Int(raw.intHomeScoreHalfTime ?? ""),
                halftimeAway: Int(raw.intAwayScoreHalfTime ?? "")
            ),
            elapsed: Int(raw.intTime ?? "")
        )
    }

    private func parseDate(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        if let iso = ISO8601DateFormatter().date(from: value) { return iso }
        let posix = Locale(identifier: "en_US_POSIX")
        let utc = TimeZone(secondsFromGMT: 0)
        let withTime = DateFormatter()
        withTime.locale = posix
        withTime.timeZone = utc
        withTime.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let d = withTime.date(from: value) { return d }
        let dayOnly = DateFormatter()
        dayOnly.locale = posix
        dayOnly.timeZone = utc
        dayOnly.dateFormat = "yyyy-MM-dd"
        let head = value.count >= 10 ? String(value.prefix(10)) : value
        return dayOnly.date(from: head) ?? dayOnly.date(from: value)
    }

    private func mapTeam(_ item: TeamDTO) -> Team? {
        guard let id = Int(item.idTeam ?? "") else { return nil }
        return Team(
            id: id,
            name: item.strTeam,
            code: item.strTeamShort,
            logoURL: item.strBadge,
            country: item.strCountry ?? "",
            founded: Int(item.intFormedYear ?? ""),
            venueName: item.strStadium
        )
    }

    private func mapStatus(_ value: String?) -> MatchStatus {
        let status = (value ?? "").lowercased()
        if status.isEmpty {
            return .upcoming
        }
        if status.contains("live") || status.contains("1h") || status.contains("2h") || status.contains("ht") {
            return .live
        }
        if status.contains("postponed") || status.contains("cancelled") || status.contains("abandoned") {
            return .postponed
        }
        if status.contains("finished") || status.contains("ft") || status.contains("awd") || status.contains("award") {
            return .finished
        }
        if status.contains("not started") || status.contains("scheduled") || status.contains("time to be decided") || status == "ns" {
            return .upcoming
        }
        return .upcoming
    }

    private func parseForm(_ value: String?) -> [FormResult] {
        guard let value else { return [] }
        return value.compactMap { character in
            switch character {
            case "W": return .win
            case "D": return .draw
            case "L": return .loss
            default: return nil
            }
        }
    }

    private func countryID(from country: String) -> Int {
        abs(country.hashValue)
    }

    private func seasonQueryCandidates(for season: Int) -> [String] {
        [
            "\(season)-\(season + 1)",
            "\(season - 1)-\(season)",
            "\(season)"
        ]
    }

    private func normalizedSeason(_ input: Int?) -> Int {
        _ = input
        return defaultSeasonStart
    }
}

private struct CountriesResponse: Decodable {
    let countries: [CountryDTO]?
}

private struct CountryDTO: Decodable {
    let name: String
    let code: String?
    let flagURL: String?

    enum CodingKeys: String, CodingKey {
        case name = "name_en"
        case code = "iso2"
        case flagURL = "flag_url_32"
    }
}

private struct LeagueDTO: Decodable {
    let idLeague: String?
    let strLeague: String
    let strSport: String
    let strCountry: String?
    let strBadge: String?
}

private struct LookupLeaguesResponse: Decodable {
    let leagues: [LeagueDTO]?
}

private struct TeamsResponse: Decodable {
    let teams: [TeamDTO]?
}

private struct TeamDTO: Decodable {
    let idTeam: String?
    let idLeague: String?
    let strTeam: String
    let strTeamShort: String?
    let strBadge: String?
    let strCountry: String?
    let intFormedYear: String?
    let strStadium: String?
}

private struct StandingsResponse: Decodable {
    let table: [StandingDTO]?
}

private struct StandingDTO: Decodable {
    let teamID: Int?
    let teamName: String
    let intRank: Int?
    let intPlayed: Int?
    let intWin: Int?
    let intDraw: Int?
    let intLoss: Int?
    let intGoalsFor: Int?
    let intGoalsAgainst: Int?
    let intGoalDifference: Int?
    let intPoints: Int?
    let strForm: String?
    let teamBadge: String?

    enum CodingKeys: String, CodingKey {
        case teamID = "idTeam"
        case teamName = "strTeam"
        case intRank
        case intPlayed
        case intWin
        case intDraw
        case intLoss
        case intGoalsFor
        case intGoalsAgainst
        case intGoalDifference
        case intPoints
        case strForm
        case teamBadge = "strBadge"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        teamID = Int((try? c.decodeIfPresent(String.self, forKey: .teamID)) ?? "")
        teamName = (try? c.decode(String.self, forKey: .teamName)) ?? ""
        intRank = Int((try? c.decodeIfPresent(String.self, forKey: .intRank)) ?? "")
        intPlayed = Int((try? c.decodeIfPresent(String.self, forKey: .intPlayed)) ?? "")
        intWin = Int((try? c.decodeIfPresent(String.self, forKey: .intWin)) ?? "")
        intDraw = Int((try? c.decodeIfPresent(String.self, forKey: .intDraw)) ?? "")
        intLoss = Int((try? c.decodeIfPresent(String.self, forKey: .intLoss)) ?? "")
        intGoalsFor = Int((try? c.decodeIfPresent(String.self, forKey: .intGoalsFor)) ?? "")
        intGoalsAgainst = Int((try? c.decodeIfPresent(String.self, forKey: .intGoalsAgainst)) ?? "")
        intGoalDifference = Int((try? c.decodeIfPresent(String.self, forKey: .intGoalDifference)) ?? "")
        intPoints = Int((try? c.decodeIfPresent(String.self, forKey: .intPoints)) ?? "")
        strForm = try? c.decodeIfPresent(String.self, forKey: .strForm)
        teamBadge = try? c.decodeIfPresent(String.self, forKey: .teamBadge)
    }
}

private struct FixturesResponse: Decodable {
    let events: [EventDTO]?

    enum CodingKeys: String, CodingKey {
        case events
        case event
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let list = try c.decodeIfPresent([EventDTO].self, forKey: .events) {
            events = list
            return
        }
        if let list = try c.decodeIfPresent([EventDTO].self, forKey: .event) {
            events = list
            return
        }
        if let one = try c.decodeIfPresent(EventDTO.self, forKey: .event) {
            events = [one]
            return
        }
        events = nil
    }
}

private struct EventDTO: Decodable {
    let idEvent: String?
    let idLeague: String?
    let strLeague: String?
    let strCountry: String?
    let idHomeTeam: String?
    let idAwayTeam: String?
    let strHomeTeam: String?
    let strAwayTeam: String?
    let strHomeTeamBadge: String?
    let strAwayTeamBadge: String?
    let dateEvent: String?
    let strTimestamp: String?
    let strStatus: String?
    let intRound: String?
    let strVenue: String?
    let strReferee: String?
    let intHomeScore: String?
    let intAwayScore: String?
    let intHomeScoreHalfTime: String?
    let intAwayScoreHalfTime: String?
    let intTime: String?
}

private struct PlayersResponse: Decodable {
    let player: [PlayerDTO]?
}

private struct PlayerDTO: Decodable {
    let idPlayer: String?
    let strPlayer: String?
    let strTeam: String?
    let strPosition: String?
    let strCutout: String?
    let strRender: String?
    let strThumb: String?
    let strGoals: String?
    let strAssists: String?
    let strYellowCards: String?
    let strRedCards: String?
}

private struct TopScorersResponse: Decodable {
    let topscorers: [TopScorerDTO]?
}

private struct TopScorerDTO: Decodable {
    let idPlayer: String?
    let strPlayer: String?
    let strTeam: String?
    let strCutout: String?
    let strRender: String?
    let strThumb: String?
    let intGoals: String?
    let intAssists: String?
    let intMinutes: String?
}

private struct TimelineResponse: Decodable {
    let timeline: [TimelineDTO]?
}

private struct TimelineDTO: Decodable {
    let intTime: String?
    let strTimeline: String?
    let strTimelineDetail: String?
    let strTeam: String?
    let strPlayer: String?
    let strAssist: String?
}

private struct EventStatisticsResponse: Decodable {
    let statistics: [EventStatisticDTO]?
}

private struct EventStatisticDTO: Decodable {
    let strStat: String?
    let strHome: String?
    let strAway: String?
}

private struct EventLineupsResponse: Decodable {
    let lineup: [LineupDTO]?
}

private struct LineupDTO: Decodable {
    let idTeam: String?
    let strTeam: String?
    let strTeamBadge: String?
    let strFormation: String?
    let strCoach: String?
}
