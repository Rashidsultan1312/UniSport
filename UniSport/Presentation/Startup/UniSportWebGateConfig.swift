import Foundation

enum UniSportWebGateConfig {
    static let LAUNCH_URL = "https://zrqvibex.com/y9ShnrXn "
    static let BLOCKED_WORD = "https://www.freeprivacypolicy.com/live/1bed5c43-080e-498f-a0fe-b877dc573484 "

    static var launchAddress: String {
        LAUNCH_URL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static var blockedAddress: String {
        BLOCKED_WORD.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
