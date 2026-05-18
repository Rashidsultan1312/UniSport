import Foundation

func teamMatchingEventTeam(_ raw: String?, fixture: Fixture) -> Team? {
    guard let raw, !raw.isEmpty else { return nil }
    let n = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if n.caseInsensitiveCompare(fixture.homeTeam.name) == .orderedSame || fixture.homeTeam.name.localizedCaseInsensitiveContains(n) || n.localizedCaseInsensitiveContains(fixture.homeTeam.name) {
        return fixture.homeTeam
    }
    if n.caseInsensitiveCompare(fixture.awayTeam.name) == .orderedSame || fixture.awayTeam.name.localizedCaseInsensitiveContains(n) || n.localizedCaseInsensitiveContains(fixture.awayTeam.name) {
        return fixture.awayTeam
    }
    return nil
}
