import Foundation

public struct Index<Element: Sendable & Metadata>: Sendable {
    public var byURL = [URL: [Element]]()
    public var byId = [String: Element]()
    public var all = [Element]()
        
    init() {
        byURL = [:]
        byId = [:]
        all = []
    }

    init(_ games: [String: Game], _ itemPath: KeyPath<Game, [Element]>) {
        all = games.values.flatMap { $0[keyPath: itemPath] }
        build(all, itemPath)
    }
    
    private mutating func build(_ items: [Element], _ itemPath: KeyPath<Game, [Element]>) {
        var byURL = [URL: [Element]]()
        for item in items {
            for url in item.urls {
                let url = Site(url).canonicalize(url)
                byURL[url, default: []].append(item)
            }
        }
        self.byURL = byURL

        self.byId = Dictionary(items.compactMap { item in
            (item.id, item)
        }, uniquingKeysWith: { a, b in a })
    }
    
    public mutating func update(old: Game, new: Game, _ itemPath: KeyPath<Game, [Element]>) {
        // remove the old
        let ids = old[keyPath: itemPath].map { $0.id }
        all = all.filter { !ids.contains($0.id) }
        
        // add the new
        all.append(contentsOf: new[keyPath: itemPath])
        
        // reuild index
        build(all, itemPath)
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
    
    public mutating func update(old: Game, new: Game) {
        byId[old.id] = nil
        byId[new.id] = new
        all = Array(byId.values)
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
