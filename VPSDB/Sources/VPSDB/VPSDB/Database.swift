import Foundation

public struct Database: Codable, Sendable {
    public var games = Index<Game>()
    public var gamesByName = [String: [Game]]()

    public var tables = Index<Table>()
    public var backglasses = Index<B2S>()
    public var tutorials = Index<Tutorial>()
    public var roms = Index<ROM>()
    public var pupPacks = Index<PupPack>()
    public var altColors = Index<AltColors>()
    public var altSounds = Index<AltSound>()
    public var sounds = Index<Sound>()
    public var povs = Index<POV>()
    public var wheels = Index<WheelArt>()
    public var toppers = Index<Topper>()
    public var mediaPacks = Index<MediaPack>()
    public var rules = Index<Rules>()
    
    public var url: URL? = nil

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()

        let games = try Dictionary(
            uniqueKeysWithValues: container.decode([GameContainer].self)
                .map {
                    ($0.game.id, $0.game)
                }
        )
        
        finish(games: games)
    }
    
    public init() {
        finish(games: [:])
    }
    
    init(url: URL?, games: [String:Game]) {
        self.url = url
        finish(games: games)
    }
    
    private mutating func finish(games: [String : Game]) {
        self.games = Index(games: games)
        self.gamesByName = Dictionary(grouping: games.values, by: \.name)

        self.tables = Index(games, \.tables)
        self.backglasses = Index(games, \.backglasses)
        self.tutorials = Index(games, \.tutorials)
        self.roms = Index(games, \.roms)
        self.pupPacks = Index(games, \.pupPacks)
        self.altColors = Index(games, \.altColors)
        self.altSounds = Index(games, \.altSounds)
        self.sounds = Index(games, \.sounds)
        self.povs = Index(games, \.povs)
        self.wheels = Index(games, \.wheels)
        self.toppers = Index(games, \.toppers)
        self.mediaPacks = Index(games, \.mediaPacks)
        self.rules = Index(games, \.rules)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(Array(self.games.all))
    }
    
    public static func load(directory: URL) throws -> Database {
        let urls = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [])
        var games = [String:Game]()
        
        for url in urls {
            let data = try Data(contentsOf: url)
            let gameContainer = try JSONDecoder().decode(GameContainer.self, from: data)
            games[gameContainer.game.id] = gameContainer.game
        }
        
        return Database(url: directory, games: games)
    }

    public subscript(kind: GameResourceKind) -> AnyIndex {
        switch kind {
        case .game: AnyIndex(games)
        case .table: AnyIndex(tables)
        case .b2s: AnyIndex(backglasses)
        case .tutorial: AnyIndex(tutorials)
        case .rom: AnyIndex(roms)
        case .pupPack: AnyIndex(pupPacks)
        case .altColor: AnyIndex(altColors)
        case .altSound: AnyIndex(altSounds)
        case .sound: AnyIndex(sounds)
        case .pov: AnyIndex(povs)
        case .wheelArt: AnyIndex(wheels)
        case .topper: AnyIndex(toppers)
        case .mediaPack: AnyIndex(mediaPacks)
        case .rule: AnyIndex(rules)
        }
    }

    public subscript(metadata: Metadata) -> Game? {
        games.byId[metadata.gameId]
    }
    
    public mutating func update(_ gameId: String, mutator: (inout Game) -> Void) throws {
        if let game = games.byId[gameId] {
            try update(game, mutator: mutator)
        }
    }
    
    public mutating func update(_ game: Game, mutator: (inout Game) -> Void) throws {
        precondition(url != nil)
        
        var new = game
        mutator(&new)
        
        if new != game {
            if let lastCreatedAt = new.tables.map({ $0.createdAt }).max() {
                new.lastCreatedAt = lastCreatedAt
                new.updatedAt = Date()
            }
            
            let url = url!.appending(component: game.id).appendingPathExtension("json")
            try JSONEncoder().encode(new).write(to: url, options: .atomic)
            
            self.games.update(old: game, new: new)
            self.gamesByName = Dictionary(grouping: games.all, by: \.name)
            
            self.tables.update(old: game, new: game, \.tables)
            self.backglasses.update(old: game, new: game, \.backglasses)
            self.tutorials.update(old: game, new: game, \.tutorials)
            self.roms.update(old: game, new: game, \.roms)
            self.pupPacks.update(old: game, new: game, \.pupPacks)
            self.altColors.update(old: game, new: game, \.altColors)
            self.altSounds.update(old: game, new: game, \.altSounds)
            self.sounds.update(old: game, new: game, \.sounds)
            self.povs.update(old: game, new: game, \.povs)
            self.wheels.update(old: game, new: game, \.wheels)
            self.toppers.update(old: game, new: game, \.toppers)
            self.mediaPacks.update(old: game, new: game, \.mediaPacks)
            self.rules.update(old: game, new: game, \.rules)
        }
    }
    
    public func search(
        kind: GameResourceKind?, query: String
    ) -> [SearchResult] {
        if query.hasPrefix("http"), let url = URL(string: query) {
            return search(kind: kind, url: url)
        }
        
        let kinds: [GameResourceKind]
        if let kind {
            kinds = [kind]
        } else {
            kinds = GameResourceKind.allCases
        }

        var result = [SearchResult]()
        
        let lowercaseQuery = query.lowercased()
        
        for game in games.all {
            let gameMatches = game.matches(lowercaseQuery)
            if gameMatches {
                for kind in kinds {
                    if kind == .game {
                        if gameMatches {
                            result.append(.init(game: game, id: game.id, kind: .game))
                        }
                    } else {
                        let resources = game[kind]
                        result.append(
                            contentsOf: resources.map {
                                .init(game: game, id: $0.id, kind: kind)
                            }
                        )
                    }
                }
            }
        }
        
        return result
    }
    
    public func search(
        kind: GameResourceKind?, url: URL
    ) -> [SearchResult] {
        let kinds: [GameResourceKind]
        if let kind {
            kinds = [kind]
        } else {
            kinds = GameResourceKind.allCases
        }
        
        var result = [SearchResult]()
        
        for game in games.all {
            for kind in kinds {
                let found = game[kind].filter {
                    $0.urls.contains(url)
                }
                if !found.isEmpty {
                    result.append(
                        contentsOf: found.map {
                            .init(game: game, id: $0.id, kind: kind)
                        }
                    )
                }
            }
        }
        
        return result
    }
    
    public func parseName(_ name: String) -> (String, Manufacturer?, Int?) {
        let year = Int(name.firstMatch(of: /\d\d\d\d/)?.0 ?? "")
        var manufacturer: Manufacturer?
        
        let priorityManufacturer: [Manufacturer] = [.original, .stern, .bally, .williams, .gottlieb]
        let lowerName = name.lowercased()
        for m in priorityManufacturer + Manufacturer.allCases {
            if lowerName.contains(m.rawValue.lowercased()) {
                manufacturer = m
                break
            }
        }
        
        return (
            String(name.split(separator: /[-(]/)[0].trimmingCharacters(in: .whitespaces)),
            manufacturer,
            year
        )
    }
    
    public func matchName(_ name: String) -> [Game] {
        // Akira Ludo242 MOD -> Akira
        // Hairy-Singers (Rally 1966) -> Hairy-Singers
        // Three Musketeers -> Three Musketeers
        // Big Trouble in Little China - Diagonale Style Wheel -> BTiLC
        // Wuthering waves (Wheels) -> Wuthering Waves
        // 2001 (Gottlieb, 1971) -> 2001
        // Back to the Future (Data East 1990) - Diagonale Style Wheel
        
        func canonicalize(_ string: String) -> String {
            String(string.lowercased().filter { $0.isLetter || $0.isNumber })
        }
        
        let (name, manufacturer, year) = parseName(name)
        let firstPart = canonicalize(name)
                
        let matches = games.all.filter { game in
            if let year {
                if game.year != year {
                    return false
                }
            }
            if let manufacturer {
                if game.manufacturer != manufacturer {
                    return false
                }
            }
            
            let gameName = canonicalize(game.name)
            
            if firstPart.contains(gameName) || gameName.contains(firstPart) {
                return true
            }
            
            return false
        }
        
        let scored = matches.map { game in
            let gameName = canonicalize(game.name)
            if gameName == firstPart {
                return (Int.max, game)
            } else {
                return (firstPart.commonPrefix(with: gameName).count, game)
            }
        }
        
        let maxScore = scored.map { $0.0 }.max() ?? 0
        return scored.filter { $0.0 == maxScore }.map { $0.1 }
    }
}

public struct SearchResult: Identifiable, Sendable {
    public let game: Game
    public let id: String
    public let kind: GameResourceKind
}
