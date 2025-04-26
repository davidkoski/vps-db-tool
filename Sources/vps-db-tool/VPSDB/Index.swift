import Foundation

struct Index<Element: Sendable & Metadata>: Sendable {
    var byURL: [URL: [Element]]
    var byId: [String: Element]
    var all: [Element]

    init(_ games: [String: Game], _ itemPath: KeyPath<Game, [Element]>) {
        byURL = Dictionary(
            grouping: games.values.flatMap { game in
                let items = game[keyPath: itemPath]
                return items.compactMap { item in
                    if item.url != nil {
                        return item
                    } else {
                        return nil
                    }
                }
            },
            by: { $0.url! }
        )
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

    subscript(url: URL) -> [Element] {
        byURL[url] ?? []
    }

    subscript(id: String) -> Element? {
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

struct AnyIndex {

    var byURL: [URL: [Metadata]]
    var byId: [String: Metadata]
    var all: [Metadata]

    init<Element: Sendable & Metadata>(_ index: Index<Element>) {
        byURL = index.byURL as [URL: [Metadata]]
        byId = index.byId as [String: Metadata]
        all = index.all as [Metadata]
    }

    subscript(url: URL) -> [Metadata] {
        byURL[url] ?? []
    }

    subscript(id: String) -> Metadata? {
        byId[id]
    }
}
