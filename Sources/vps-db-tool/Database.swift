import Foundation
import MetaCodable
import HelperCoders

enum Site: Sendable {
    case vpuniverse
    case vpforums
    case pinballnirvana
    case other
}

@Codable
struct Resource: Sendable {
    let url: URL
    @Default(false) let broken: Bool
    
    var site: Site {
        switch url.host() {
        case "vpuniverse.com": .vpuniverse
        case "www.vpforums.org": .vpforums
        case "pinballnirvana.com": .pinballnirvana
        default: .other
        }
    }
}

@Codable
struct GameRef: Sendable {
    let id: String
    let name: String
}

struct Author: Codable, Sendable, Hashable, Comparable {
    let name: String
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.name = try container.decode(String.self)
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.name)
    }
    
    static func < (lhs: Author, rhs: Author) -> Bool {
        lhs.name < rhs.name
    }
}

struct Theme: Codable, Sendable, Hashable, Comparable {
    let name: String
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.name = try container.decode(String.self)
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.name)
    }
    
    static func < (lhs: Theme, rhs: Theme) -> Bool {
        lhs.name < rhs.name
    }
}

struct Feature: Codable, Sendable, Hashable, Comparable {
    let name: String
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.name = try container.decode(String.self)
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.name)
    }
    
    static func < (lhs: Feature, rhs: Feature) -> Bool {
        lhs.name < rhs.name
    }
}

enum TableFormat: String, Codable, Hashable, Sendable {
    case FP
    case FX
    case FX2
    case FX3
    case VP9
    case VPX
}

enum Kind: String, Codable, Hashable, Sendable {
    case EM
    case SS
    case PM
}

@Codable
struct Metadata: Sendable {
    @CodedBy(Since1970DateCoder()) @Default(ifMissing: Date())
    let createdAt: Date
    @CodedBy(Since1970DateCoder()) @Default(ifMissing: Date())
    let updatedAt: Date
    
    let comment: String?
    
    @Default(ifMissing: GameRef(id: "", name: ""))
    var game: GameRef
    
    @Default([])
    let urls: [Resource]
    
    @Default([])
    let authors: [Author]
    
    let version: String?
}

protocol HasMetadata {
    var id: String { get }
    var meta: Metadata { get set }
    
    var url: URL? { get }
    var site: Site { get }
    var gameId: String { get }
}

extension HasMetadata {
    var url: URL? {
        meta.urls.first?.url
    }
    
    var site: Site {
        meta.urls.first?.site ?? .other
    }
    
    var gameId: String {
        meta.game.id
    }
}

@Codable
struct Table: HasMetadata, Sendable {
    let id: String
    
    @CodedAt
    var meta: Metadata
    
    @Default([])
    let features: Set<Feature>
    @Default<TableFormat?>(nil) let tableFormat: TableFormat?
    let edition: String?
    
    @Default<URL?>(nil)
    let imgUrl: URL?
}

@Codable
struct B2S: HasMetadata, Sendable {
    // Note: b2s for FX tables don't have an id
    @Default(ifMissing: UUID().uuidString)
    let id: String
    
    @CodedAt
    var meta: Metadata
    
    @Default([])
    let features: Set<Feature>?
    let imgUrl: URL?
}

@Codable
struct Tutorial: HasMetadata, Sendable {
    let id: String
    
    @CodedAt
    var meta: Metadata

    let youtubeId: String
    let title: String
}

@Codable
struct ROM: HasMetadata, Sendable {
    let id: String
    
    @CodedAt
    var meta: Metadata
}

@Codable
struct PupPack: HasMetadata, Sendable {
    let id: String
    
    @CodedAt
    var meta: Metadata
}

@Codable
struct AltColors: HasMetadata, Sendable {
    let id: String
    
    @CodedAt
    var meta: Metadata
}

@Codable
struct AltSound: HasMetadata, Sendable {
    let id: String
    
    @CodedAt
    var meta: Metadata
}

@Codable
struct POV: HasMetadata, Sendable {
    let id: String
    
    @CodedAt
    var meta: Metadata
}

@Codable
struct WheelArt: HasMetadata, Sendable {
    let id: String
    
    @CodedAt
    var meta: Metadata
}

@Codable
struct Topper: HasMetadata, Sendable {
    let id: String
    
    @CodedAt
    var meta: Metadata
}

@Codable
struct MediaPack: HasMetadata, Sendable {
    let id: String
    
    @CodedAt
    var meta: Metadata
}

@Codable
struct Rules: HasMetadata, Sendable {
    let id: String
    
    @CodedAt
    var meta: Metadata
}

struct GameDecodeError: Error {
    let id: String
    let name: String
    let error: Error
}

/// container to help find errors in decoding
struct GameContainer: Decodable {
    let game: Game
    
    init(from decoder: any Decoder) throws {
        do {
            self.game = try Game(from: decoder)
        } catch {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let id = try container.decodeIfPresent(String.self, forKey: .id) ?? "missing"
            let name = try container.decodeIfPresent(String.self, forKey: .name) ?? "missing"
            throw GameDecodeError(id: id, name: name, error: error)
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id = "id"
        case name = "name"
    }
}

@Codable
struct Game: Sendable {
    let id: String

    @CodedBy(Since1970DateCoder())
    let lastCreatedAt: Date
    @CodedBy(Since1970DateCoder())
    let updatedAt: Date
    
    let name: String
    let manufacturer: String
    let imageUrl: URL?
    
    @CodedAt("MPU") let mpu: String?
    let year: Int?
    
    @Default([]) let theme: Set<Theme>

    @Default([]) let designers: Set<String>
    
    let type: Kind?
    let players: Int?
    let ipdbUrl: URL?
    
    @CodedAt("tableFiles") @Default(ifMissing: []) var tables: [Table]
    @CodedAt("b2sFiles") @Default(ifMissing: []) var backglasses: [B2S]
    @CodedAt("tutorialFiles") @Default(ifMissing: []) var tutorials: [Tutorial]
    @CodedAt("romFiles") @Default(ifMissing: []) var roms: [ROM]
    @CodedAt("pupPackFiles") @Default(ifMissing: []) var pupPacks: [PupPack]
    @CodedAt("altColorFiles") @Default(ifMissing: []) var altColors: [AltColors]
    @CodedAt("altSoundFiles") @Default(ifMissing: []) var altSounds: [AltSound]
    @CodedAt("povFiles") @Default(ifMissing: []) var povs: [POV]
    @CodedAt("wheelArtFiles") @Default(ifMissing: []) var wheels: [WheelArt]
    @CodedAt("topperFiles") @Default(ifMissing: []) var toppers: [Topper]
    @CodedAt("mediaPackFiles") @Default(ifMissing: []) var mediaPacks: [MediaPack]
    @CodedAt("ruleFiles") @Default(ifMissing: []) var rules: [Rules]

    @Default(false) let broken: Bool
}

struct Index<Element: Sendable & HasMetadata>: Sendable {
    var byURL: [URL:Element]
    var byId: [String:Element]
    var all: [Element]

    init(_ games: [String:Game], _ itemPath: KeyPath<Game, [Element]>) {
        byURL = Dictionary(
            games.values.flatMap { game in
                let items = game[keyPath: itemPath]
                return items.compactMap { item in
                    if let url = item.meta.urls.first?.url {
                        return (url, item)
                    } else {
                        return nil
                    }
                }
            },
            uniquingKeysWith: { a, b in a }
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
    
    subscript(url: URL) -> Element? {
        byURL[url]
    }
    
    subscript(id: String) -> Element? {
        byId[id]
    }
}

struct Database: Codable, Sendable {
    var games: [String:Game]

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
        
        func connect<T: HasMetadata>(_ game: inout Game, _ keyPath: WritableKeyPath<Game, [T]>) {
            let id = GameRef(id: game.id, name: game.name)
            game[keyPath: keyPath] = game[keyPath: keyPath].map { i in
                var i = i
                i.meta.game = id
                return i
            }
        }
        
        self.games = try Dictionary(
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
        try container.encode(Array(self.games.values))
    }
}
