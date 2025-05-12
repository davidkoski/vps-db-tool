import Foundation

enum GameIssue: Codable, Sendable, Hashable {
    case emptyThemes

    func describe(game: Game) -> String {
        switch self {
        case .emptyThemes:
            "\(game): empty themes"
        }
    }
}

enum TableIssue: Codable, Sendable, Hashable {
    case missingModFeature

    func describe(game: Game, table: Table) -> String {
        let prefix = "\(game) \(table.id):"
        return switch self {
        case .missingModFeature:
            "\(prefix) missing MOD feature"
        }
    }
}

enum ResourceIssue: Codable, Sendable, Hashable {
    case versionMismatch(String?)

    func describe(game: Game, kind: GameResourceKind, gameResource: Metadata) -> String {
        let prefix = "\(game) \(kind.rawValue) \(gameResource.id):"
        return switch self {
        case .versionMismatch(let v):
            "\(prefix) version mismatch \(canonicalVersion(gameResource.version)) != \(canonicalVersion(v))"
        }
    }
}

enum URLIssue: Codable, Sendable, Hashable {
    case entryNotFound(DetailResult)

    func describe(kind: GameResourceKind, url: URL) -> String {
        switch self {
        case .entryNotFound(let d):
            "\(kind.rawValue): not found \(url)\n\t\(d)"
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .entryNotFound(let detailResult):
            // match on tag only
            hasher.combine("entryNotFound")
            break
        }
    }

    static func == (lhs: URLIssue, rhs: URLIssue) -> Bool {
        switch (lhs, rhs) {
        case (.entryNotFound(let l), .entryNotFound(let r)):
            // match on tag only
            return true
        default:
            return false
        }
    }
}

struct IssueMetadata: Codable, Sendable, CustomStringConvertible {
    var comment = ""
    var date = Date()

    var description: String {
        "Entry: \(date.formatted(date: .abbreviated, time: .omitted)) \(comment)"
    }
}

struct IssueDatabase: Codable, Sendable {

    var gameIssues = [String: [GameIssue: IssueMetadata]]()
    var tableIssues = [String: [TableIssue: IssueMetadata]]()
    var resourceIssue = [GameResourceKind: [String: [ResourceIssue: IssueMetadata]]]()
    var urlIssue = [GameResourceKind: [URL: [URLIssue: IssueMetadata]]]()

    subscript(game: Game, issue: GameIssue) -> IssueMetadata? {
        get {
            gameIssues[game.id]?[issue]
        }
        set {
            gameIssues[game.id, default: [:]][issue] = newValue
        }
    }

    subscript(table: Table, issue: TableIssue) -> IssueMetadata? {
        get {
            tableIssues[table.id]?[issue]
        }
        set {
            tableIssues[table.id, default: [:]][issue] = newValue
        }
    }

    subscript(resourceKind: GameResourceKind, gameResource: Metadata, issue: ResourceIssue)
        -> IssueMetadata?
    {
        get {
            resourceIssue[resourceKind]?[gameResource.id]?[issue]
        }
        set {
            resourceIssue[resourceKind, default: [:]][gameResource.id, default: [:]][issue] =
                newValue
        }
    }

    subscript(resourceKind: GameResourceKind, url: URL, issue: URLIssue) -> IssueMetadata? {
        get {
            urlIssue[resourceKind]?[Site.canonical(url)]?[issue]
        }
        set {
            urlIssue[resourceKind, default: [:]][Site.canonical(url), default: [:]][issue] =
                newValue
        }
    }

    enum IssueDisposition {
        case existant
        case recorded
        case willFix
    }

    @discardableResult
    mutating func report(game: Game, issue: GameIssue) -> IssueDisposition {
        print(issue.describe(game: game))
        if let found = self[game, issue] {
            print(found)
            return .existant
        } else {
            print("Comment or <return> to skip")
            if let line = readLine(), !line.isEmpty {
                self[game, issue] = .init(comment: line)
                return .recorded
            } else {
                return .willFix
            }
        }
    }

    @discardableResult
    mutating func report(game: Game, table: Table, issue: TableIssue) -> IssueDisposition {
        print(issue.describe(game: game, table: table))
        if let found = self[table, issue] {
            print(found)
            return .existant
        } else {
            print("Comment or <return> to skip")
            if let line = readLine(), !line.isEmpty {
                self[table, issue] = .init(comment: line)
                return .recorded
            } else {
                return .willFix
            }
        }
    }

    @discardableResult
    mutating func report(
        game: Game, kind: GameResourceKind, gameResource: Metadata, url: URL, issue: ResourceIssue
    ) -> IssueDisposition {
        print(url)
        print(issue.describe(game: game, kind: kind, gameResource: gameResource))
        if let found = self[kind, gameResource, issue] {
            print(found)
            return .existant
        } else {
            print("Comment or <return> to skip")
            if let line = readLine(), !line.isEmpty {
                self[kind, gameResource, issue] = .init(comment: line)
                return .recorded
            } else {
                return .willFix
            }
        }
    }

    @discardableResult
    mutating func report(kind: GameResourceKind, url: URL, issue: URLIssue, comment: String? = nil)
        -> IssueDisposition
    {
        print(issue.describe(kind: kind, url: url))
        if let found = self[kind, url, issue] {
            print(found)
            return .existant
        } else {
            if let comment = resolveComment(comment) {
                self[kind, url, issue] = .init(comment: comment)
                return .recorded
            } else {
                return .willFix
            }
        }
    }

    func resolveComment(_ comment: String?) -> String? {
        if let comment {
            return comment
        }
        print("Comment or <return> to skip")
        if let line = readLine(), !line.isEmpty {
            return line
        }
        return nil
    }

    func check(game: Game, issue: GameIssue) -> Bool {
        self[game, issue] != nil
    }

    func check(game: Game, table: Table, issue: TableIssue) -> Bool {
        self[table, issue] != nil
    }

    func check(
        game: Game, kind: GameResourceKind, gameResource: Metadata, url: URL, issue: ResourceIssue
    ) -> Bool {
        self[kind, gameResource, issue] != nil
    }

    func check(kind: GameResourceKind, url: URL, issue: URLIssue) -> Bool {
        self[kind, url, issue] != nil
    }

}
