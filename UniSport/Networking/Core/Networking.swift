import Foundation
import OSLog

enum UniSportLog {
    private static let logger = Logger(subsystem: "com.unisport.app", category: "general")

    static func api(_ message: String) {
        #if DEBUG
        logger.debug("[UniSport/API] \(message, privacy: .public)")
        #endif
    }

    static func vm(_ message: String) {
        #if DEBUG
        logger.debug("[UniSport/VM] \(message, privacy: .public)")
        #endif
    }

    static func repo(_ message: String) {
        #if DEBUG
        logger.debug("[UniSport/Repo] \(message, privacy: .public)")
        #endif
    }

    static func error(_ message: String) {
        logger.error("[UniSport/Error] \(message, privacy: .public)")
    }
}

enum NetworkError: LocalizedError {
    case invalidURL
    case requestFailed
    case badStatus(Int)
    case decodingFailed
    case unauthorized
    case rateLimited
    case noData

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The request URL is invalid."
        case .requestFailed:
            return "The network request failed."
        case .badStatus(let code):
            return "The server responded with status code \(code)."
        case .decodingFailed:
            return "The response could not be decoded."
        case .unauthorized:
            return "The API key is missing or invalid."
        case .rateLimited:
            return "The API request limit has been reached."
        case .noData:
            return "The server returned no data."
        }
    }
}

struct APIConfig {
    let baseURL: URL
    let apiKey: String
    let requestTimeout: TimeInterval
    let liveTimeout: TimeInterval

    var isConfigured: Bool {
        !apiKey.isEmpty
    }
}

struct APIRequest {
    let path: String
    let queryItems: [URLQueryItem]
    let timeout: TimeInterval?
}

protocol HTTPClient {
    func send<T: Decodable>(_ request: APIRequest, as type: T.Type) async throws -> T
}

struct APIFootballEnvelope<T: Decodable>: Decodable {
    let response: T
}

final class URLSessionHTTPClient: HTTPClient {
    private let session: URLSession
    private let config: APIConfig
    private let decoder: JSONDecoder

    init(session: URLSession = .shared, config: APIConfig) {
        self.session = session
        self.config = config
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    func send<T: Decodable>(_ request: APIRequest, as type: T.Type) async throws -> T {
        let base = config.baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let pathPart = request.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard var components = URLComponents(string: "\(base)/\(pathPart)") else {
            throw NetworkError.invalidURL
        }
        components.queryItems = request.queryItems.isEmpty ? nil : request.queryItems
        guard let url = components.url else {
            throw NetworkError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.timeoutInterval = request.timeout ?? config.requestTimeout
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        UniSportLog.api("→ GET \(url.lastPathComponent)")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            if error is CancellationError {
                throw error
            }
            if let urlErr = error as? URLError, urlErr.code == .cancelled {
                throw CancellationError()
            }
            UniSportLog.error("transport \(url.lastPathComponent): \(String(describing: error))")
            throw NetworkError.requestFailed
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            UniSportLog.error("no HTTPURLResponse \(url.lastPathComponent)")
            throw NetworkError.requestFailed
        }

        switch httpResponse.statusCode {
        case 200..<300:
            UniSportLog.api("← \(httpResponse.statusCode) \(data.count)b \(url.lastPathComponent)")
        case 401, 403:
            UniSportLog.error("\(httpResponse.statusCode) unauthorized \(url.lastPathComponent)")
            throw NetworkError.unauthorized
        case 429:
            UniSportLog.error("429 rate limit \(url.lastPathComponent)")
            throw NetworkError.rateLimited
        default:
            UniSportLog.error("\(httpResponse.statusCode) \(url.lastPathComponent)")
            throw NetworkError.badStatus(httpResponse.statusCode)
        }

        if data.isEmpty {
            UniSportLog.error("empty body \(url.lastPathComponent)")
            throw NetworkError.noData
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            UniSportLog.error("decode \(String(describing: T.self)) \(String(describing: error)) url=\(url.lastPathComponent)")
            throw NetworkError.decodingFailed
        }
    }
}

enum APIFootballEndpoint {
    case leagues(country: String?, season: Int?)
    case leagueDetails(leagueID: Int)
    case teams(leagueID: Int, season: Int)
    case standings(leagueID: Int, season: Int)
    case standingsRaw(leagueID: Int, seasonQuery: String?)
    case fixtures(leagueID: Int, season: Int, teamID: Int?, date: Date?, status: MatchStatus?)
    case fixturesRaw(leagueID: Int, seasonQuery: String)
    case nextLeagueFixtures(leagueID: Int)
    case liveFixtures
    case fixtureByID(fixtureID: Int)
    case fixtureEvents(fixtureID: Int)
    case fixtureStatistics(fixtureID: Int)
    case fixtureLineups(fixtureID: Int)
    case players(teamID: Int, season: Int)
    case topScorers(leagueID: Int, season: Int)
    case searchTeams(query: String)
    case searchEvents(query: String)
    case countries

    func request(apiKey: String) -> APIRequest {
        switch self {
        case .leagues(let country, let season):
            _ = season
            return APIRequest(
                path: "\(apiKey)/search_all_leagues.php",
                queryItems: [
                    country.map { URLQueryItem(name: "c", value: $0) },
                    URLQueryItem(name: "s", value: "Soccer")
                ].compactMap { $0 },
                timeout: nil
            )
        case .leagueDetails(let leagueID):
            return APIRequest(
                path: "\(apiKey)/lookupleague.php",
                queryItems: [URLQueryItem(name: "id", value: String(leagueID))],
                timeout: nil
            )
        case .teams(let leagueID, let season):
            _ = season
            return APIRequest(
                path: "\(apiKey)/search_all_teams.php",
                queryItems: [URLQueryItem(name: "id", value: String(leagueID))],
                timeout: nil
            )
        case .standings(let leagueID, let season):
            return APIRequest(
                path: "\(apiKey)/lookuptable.php",
                queryItems: [
                    URLQueryItem(name: "l", value: String(leagueID)),
                    URLQueryItem(name: "s", value: "\(season)-\(season + 1)")
                ],
                timeout: nil
            )
        case .standingsRaw(let leagueID, let seasonQuery):
            return APIRequest(
                path: "\(apiKey)/lookuptable.php",
                queryItems: [
                    URLQueryItem(name: "l", value: String(leagueID)),
                    seasonQuery.map { URLQueryItem(name: "s", value: $0) }
                ].compactMap { $0 },
                timeout: nil
            )
        case .fixtures(let leagueID, let season, let teamID, let date, let status):
            _ = teamID
            _ = date
            _ = status
            return APIRequest(
                path: "\(apiKey)/eventsseason.php",
                queryItems: [
                    URLQueryItem(name: "id", value: String(leagueID)),
                    URLQueryItem(name: "s", value: "\(season)-\(season + 1)")
                ],
                timeout: nil
            )
        case .fixturesRaw(let leagueID, let seasonQuery):
            return APIRequest(
                path: "\(apiKey)/eventsseason.php",
                queryItems: [
                    URLQueryItem(name: "id", value: String(leagueID)),
                    URLQueryItem(name: "s", value: seasonQuery)
                ],
                timeout: nil
            )
        case .nextLeagueFixtures(let leagueID):
            return APIRequest(
                path: "\(apiKey)/eventsnextleague.php",
                queryItems: [URLQueryItem(name: "id", value: String(leagueID))],
                timeout: nil
            )
        case .liveFixtures:
            return APIRequest(
                path: "\(apiKey)/eventsday.php",
                queryItems: [URLQueryItem(name: "d", value: DateFormatters.apiDate.string(from: Date()))],
                timeout: 8
            )
        case .fixtureByID(let fixtureID):
            return APIRequest(path: "\(apiKey)/lookupevent.php", queryItems: [URLQueryItem(name: "id", value: String(fixtureID))], timeout: nil)
        case .fixtureEvents(let fixtureID):
            return APIRequest(path: "\(apiKey)/lookuptimeline.php", queryItems: [URLQueryItem(name: "id", value: String(fixtureID))], timeout: nil)
        case .fixtureStatistics(let fixtureID):
            return APIRequest(path: "\(apiKey)/lookupeventstats.php", queryItems: [URLQueryItem(name: "id", value: String(fixtureID))], timeout: nil)
        case .fixtureLineups(let fixtureID):
            return APIRequest(path: "\(apiKey)/lookuplineup.php", queryItems: [URLQueryItem(name: "id", value: String(fixtureID))], timeout: nil)
        case .players(let teamID, let season):
            _ = season
            return APIRequest(
                path: "\(apiKey)/lookup_all_players.php",
                queryItems: [
                    URLQueryItem(name: "id", value: String(teamID))
                ],
                timeout: nil
            )
        case .topScorers(let leagueID, let season):
            _ = season
            return APIRequest(
                path: "\(apiKey)/lookuptopscorers.php",
                queryItems: [URLQueryItem(name: "l", value: String(leagueID))],
                timeout: nil
            )
        case .searchTeams(let query):
            return APIRequest(path: "\(apiKey)/searchteams.php", queryItems: [URLQueryItem(name: "t", value: query)], timeout: nil)
        case .searchEvents(let query):
            return APIRequest(path: "\(apiKey)/searchevents.php", queryItems: [URLQueryItem(name: "e", value: query)], timeout: nil)
        case .countries:
            return APIRequest(path: "\(apiKey)/all_countries.php", queryItems: [], timeout: nil)
        }
    }
}

enum DateFormatters {
    static let apiDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    static let matchDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "en_US")
        return formatter
    }()
}
