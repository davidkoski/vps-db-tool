import Foundation

public struct Index<Element: Sendable & Metadata>: Sendable {
    public var byURL: [URL: [Element]]
    public var byId: [String: Element]
    public var all: [Element]

    init(_ games: [String: Game], _ itemPath: KeyPath<Game, [Element]>) {
        var byURL = [URL: [Element]]()
        for game in games.values {
            for item in game[keyPath: itemPath] {
                for url in item.urls {
                    let url = Site(url).canonicalize(url)
                    byURL[url, default: []].append(item)
                }
            }
        }
        self.byURL = byURL

        byId = Dictionary(
            games.values.flatMap { game in
                let items = game[keyPath: itemPath]
                return items.compactMap { item in
                    (item.id, item)
                }
            },
            uniquingKeysWith: { a, b in a }
        )
        all = games.values.flatMap { $0[keyPath: itemPath] }
    }

    public subscript(url: URL) -> [Element]? {
        byURL[Site(url).canonicalize(url)]
    }

    public subscript(id: String) -> Element? {
        byId[id]
    }
}

extension Index where Element == Game {
    init(games: [String: Game]) {
        byURL = .init()
        byId = games
        all = Array(games.values)
    }
}

public struct AnyIndex {

    public var byURL: [URL: [Metadata]]
    public var byId: [String: Metadata]
    public var all: [Metadata]

    public init<Element: Sendable & Metadata>(_ index: Index<Element>) {
        byURL = index.byURL as [URL: [Metadata]]
        byId = index.byId as [String: Metadata]
        all = index.all as [Metadata]
    }

    public subscript(url: URL) -> [Metadata]? {
        byURL[Site(url).canonicalize(url)]
    }

    public subscript(id: String) -> Metadata? {
        byId[id]
    }
}
