import Foundation

enum BootstrapState: Equatable {
    case launching
    case onboarding
    case ready
    case failed(String)
}

enum AppTab: String, CaseIterable, Identifiable {
    case home
    case live
    case leagues
    case search
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home:
            return "Home"
        case .live:
            return "Live"
        case .leagues:
            return "Leagues"
        case .search:
            return "Search"
        case .settings:
            return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .home:
            return "house.fill"
        case .live:
            return "dot.radiowaves.left.and.right"
        case .leagues:
            return "shield.lefthalf.filled"
        case .search:
            return "magnifyingglass"
        case .settings:
            return "gearshape.fill"
        }
    }
}

enum MatchStatus: String, Codable, CaseIterable {
    case upcoming
    case live
    case finished
    case postponed

    var title: String {
        switch self {
        case .upcoming:
            return "Upcoming"
        case .live:
            return "Live"
        case .finished:
            return "Finished"
        case .postponed:
            return "Postponed"
        }
    }
}

enum FormResult: String, Codable {
    case win = "W"
    case draw = "D"
    case loss = "L"
}

enum DataState<Value> {
    case idle
    case loading
    case success(Value, isStale: Bool = false)
    case empty(String)
    case failure(String)
}

struct AppContextSelection: Codable, Equatable {
    var country: Country?
    var season: Season?
    var league: League?
    var team: Team?

    static let empty = AppContextSelection(country: nil, season: nil, league: nil, team: nil)
}
