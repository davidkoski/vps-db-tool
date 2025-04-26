import Foundation

struct Database: Codable, Sendable {
    var games: Index<Game>

    let tables: Index<Table>
    let backglasses: Index<B2S>
    let tutorials: Index<Tutorial>
    let roms: Index<ROM>
    let pupPacks: Index<PupPack>
    let altColors: Index<AltColors>
    let altSounds: Index<AltSound>
    let povs: Index<POV>
    let wheels: Index<WheelArt>
    let toppers: Index<Topper>
    let mediaPacks: Index<MediaPack>
    let rules: Index<Rules>

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()

        func connect<T: GameResource>(_ game: inout Game, _ keyPath: WritableKeyPath<Game, [T]>) {
            let id = GameRef(id: game.id, name: game.name)
            game[keyPath: keyPath] = game[keyPath: keyPath].map { i in
                var i = i
                i.gameResource.game = id
                return i
            }
        }

        let games = try Dictionary(
            uniqueKeysWithValues: container.decode([GameContainer].self)
                .map { $0.game }
                .map { game in
                    var game = game
                    connect(&game, \.tables)
                    connect(&game, \.backglasses)
                    connect(&game, \.tutorials)
                    connect(&game, \.roms)
                    connect(&game, \.pupPacks)
                    connect(&game, \.altColors)
                    connect(&game, \.altSounds)
                    connect(&game, \.povs)
                    connect(&game, \.wheels)
                    connect(&game, \.toppers)
                    connect(&game, \.mediaPacks)
                    connect(&game, \.rules)
                    return game
                }
                .map {
                    ($0.id, $0)
                }
        )
        self.games = Index(games: games)

        self.tables = Index(games, \.tables)
        self.backglasses = Index(games, \.backglasses)
        self.tutorials = Index(games, \.tutorials)
        self.roms = Index(games, \.roms)
        self.pupPacks = Index(games, \.pupPacks)
        self.altColors = Index(games, \.altColors)
        self.altSounds = Index(games, \.altSounds)
        self.povs = Index(games, \.povs)
        self.wheels = Index(games, \.wheels)
        self.toppers = Index(games, \.toppers)
        self.mediaPacks = Index(games, \.mediaPacks)
        self.rules = Index(games, \.rules)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(Array(self.games.all))
    }

    subscript(kind: GameResourceKind) -> AnyIndex {
        switch kind {
        case .game: AnyIndex(games)
        case .table: AnyIndex(tables)
        case .b2s: AnyIndex(backglasses)
        case .tutorial: AnyIndex(tutorials)
        case .rom: AnyIndex(roms)
        case .pupPack: AnyIndex(pupPacks)
        case .altColor: AnyIndex(altColors)
        case .altSound: AnyIndex(altSounds)
        case .pov: AnyIndex(povs)
        case .wheelArt: AnyIndex(wheels)
        case .topper: AnyIndex(toppers)
        case .mediaPack: AnyIndex(mediaPacks)
        case .rule: AnyIndex(rules)
        }
    }

    subscript(metadata: Metadata) -> Game? {
        games.byId[metadata.gameId]
    }
}
