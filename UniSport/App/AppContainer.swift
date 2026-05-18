import Foundation
import Combine

struct AppEnvironment {
    let apiConfig: APIConfig

    nonisolated static func live() -> AppEnvironment {
        let apiKey = ProcessInfo.processInfo.environment["THESPORTSDB_API_KEY"] ?? ""
        guard let baseURL = URL(string: "https://www.thesportsdb.com/api/v1/json/") else {
            fatalError("Invalid API base URL")
        }
        return AppEnvironment(
            apiConfig: APIConfig(
                baseURL: baseURL,
                apiKey: apiKey.isEmpty ? "123" : apiKey,
                requestTimeout: 30,
                liveTimeout: 15
            )
        )
    }
}

final class AppContainer: ObservableObject {
    let environment: AppEnvironment
    let settingsRepository: UserSettingsRepository
    let favoritesRepository: FavoritesRepository
    let leagueRepository: LeagueRepository
    let teamRepository: TeamRepository
    let fixtureRepository: FixtureRepository
    let searchRepository: SearchRepository

    init(environment: AppEnvironment = .live()) {
        self.environment = environment
        let diskCache = DiskCache()
        let keyValueStore = KeyValueStore.shared
        let settingsRepository = AppSettingsStore(store: keyValueStore, diskCache: diskCache)
        let favoritesRepository = DefaultFavoritesRepository(store: keyValueStore)
        let httpClient = URLSessionHTTPClient(config: environment.apiConfig)
        let apiRepository = APIFootballRepository(
            client: httpClient,
            favoritesRepository: favoritesRepository,
            settingsRepository: settingsRepository,
            cache: diskCache,
            config: environment.apiConfig
        )

        self.settingsRepository = settingsRepository
        self.favoritesRepository = favoritesRepository
        self.leagueRepository = apiRepository
        self.teamRepository = apiRepository
        self.fixtureRepository = apiRepository
        self.searchRepository = apiRepository
    }
}
