import Foundation

/// Why an update (a scanned ``DetailResult``, keyed by its canonical url) is
/// suppressed -- i.e. shouldn't be offered as an update.
public enum SuppressionReason: Codable, Sendable, Hashable {

    /// Never update, e.g. the page isn't a table / resource.
    case permanent

    /// Don't show it for a while.
    case temporary(until: Date)

    /// The version (as parsed) is bad, e.g. the user supplied version is wrong
    /// or the parsing picks up junk.  Suppressed while the parsed version
    /// stays the same.
    case version(parsed: String)

    /// For a game that isn't in the database.  `name` is the parsed game name
    /// (to test for later, when the game is added); `falsePositives` are ids
    /// of games it matched that aren't right (empty if it matched none).
    case missingGame(name: String, falsePositives: Set<String>)

    /// Should be ignored (static, without db or detail knowledge)
    public func shouldSuppress() -> Bool {
        switch self {
        case .permanent: true
        case .temporary(let until): Date() < until
        case .version: false
        case .missingGame: false
        }
    }

    /// Dynamic suppress evaluation with detail result (name) and db (lookups)
    public func shouldSuppress(detail: DetailResult, db: Database) -> Bool {
        switch self {
        case .permanent:
            return true
        case .temporary(let until):
            return Date() < until
        case .version(let parsed):
            return detail.version == parsed
        case .missingGame(let name, let falsePositives):
            let newName = ParsedGameName(detail.name).name
            if name != newName {
                // name changed, take a look
                return false
            }

            // search by name -- if we find anything, look at it
            let games = db.matchName(name)
                .filter { !falsePositives.contains($0.id) }

            return games.isEmpty
        }
    }
}

extension SuppressionReason {

    /// A temporary suppression for `components` (e.g. 1 week) from `date`.
    public static func temporary(
        for components: DateComponents, from date: Date = Date(),
        calendar: Calendar = .current
    ) -> SuppressionReason {
        .temporary(until: calendar.date(byAdding: components, to: date) ?? date)
    }
}
