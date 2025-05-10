import Foundation
import ReerCodable

func canonicalVersion(_ string: String?) -> String {
    (string ?? "")
        .replacingOccurrences(of: "v", with: "")
        .replacingOccurrences(of: " ", with: "")
        .replacingOccurrences(of: ".0.0", with: ".0")
}

protocol Metadata {
    var id: String { get }
    var version: String? { get }
    var createdAt: Date { get }
    var updatedAt: Date { get }
    var gameId: String { get }
    var gameName: String { get }
    var url: URL? { get }
    var urls: [URL] { get }
}

@Codable
struct Resource: Sendable, Codable {
    var url: URL

    @CustomCoding(OmitIfFalse.self)
    var broken: Bool
}

@Codable
struct GameRef: Sendable {
    let id: String
    let name: String
}

@Codable
struct Table: GameResource, Sendable {
    let id: String

    @CustomCoding(GameResourceCommonTransformer.self)
    var gameResource: GameResourceCommon

    @CustomCoding(OmitEmpty<Set<TableFeature>>.self) let features: Set<TableFeature>
    let tableFormat: TableFormat?
    let edition: String?

    let imgUrl: URL?
}

@Codable
struct B2S: GameResource, Sendable {
    // Note: b2s for FX tables don't have an id
    @CodingKey("id")
    var _id: String?
    var id: String { _id ?? "" }

    @CustomCoding(GameResourceCommonTransformer.self)
    var gameResource: GameResourceCommon

    var imgUrl: URL?
}

@Codable
struct Tutorial: GameResource, Sendable {
    let id: String

    @CustomCoding(GameResourceCommonTransformer.self)
    var gameResource: GameResourceCommon

    var youtubeId: String
    var title: String
}

@Codable
struct ROM: GameResource, Sendable {
    let id: String

    @CustomCoding(GameResourceCommonTransformer.self)
    var gameResource: GameResourceCommon
}

@Codable
struct PupPack: GameResource, Sendable {
    let id: String

    @CustomCoding(GameResourceCommonTransformer.self)
    var gameResource: GameResourceCommon
}

@Codable
struct AltColors: GameResource, Sendable {
    let id: String

    @CustomCoding(GameResourceCommonTransformer.self)
    var gameResource: GameResourceCommon
}

@Codable
struct AltSound: GameResource, Sendable {
    let id: String

    @CustomCoding(GameResourceCommonTransformer.self)
    var gameResource: GameResourceCommon
}

@Codable
struct POV: GameResource, Sendable {
    let id: String

    @CustomCoding(GameResourceCommonTransformer.self)
    var gameResource: GameResourceCommon
}

@Codable
struct WheelArt: GameResource, Sendable {
    let id: String

    @CustomCoding(GameResourceCommonTransformer.self)
    var gameResource: GameResourceCommon
}

@Codable
struct Topper: GameResource, Sendable {
    let id: String

    @CustomCoding(GameResourceCommonTransformer.self)
    var gameResource: GameResourceCommon
}

@Codable
struct MediaPack: GameResource, Sendable {
    let id: String

    @CustomCoding(GameResourceCommonTransformer.self)
    var gameResource: GameResourceCommon
}

@Codable
struct Rules: GameResource, Sendable {
    let id: String

    @CustomCoding(GameResourceCommonTransformer.self)
    var gameResource: GameResourceCommon
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
struct Game: Metadata, Sendable, CustomStringConvertible {

    let id: String

    @CustomCoding(OmitDateUnixEpoch.self) var createdAt: Date
    @CustomCoding(OmitDateUnixEpoch.self) var updatedAt: Date

    @CustomCoding(OmitDateUnixEpoch.self) var lastCreatedAt: Date

    var name: String
    var manufacturer: Manufacturer
    var imageUrl: URL?

    @CodingKey("MPU") let mpu: String?
    var year: Int?

    @CustomCoding(OmitEmpty<Set<Theme>>.self) var theme: Set<Theme>

    @CustomCoding(OmitEmpty<Set<String>>.self) var designers: Set<String>

    var type: Kind?
    var players: Int?
    var ipdbUrl: URL?

    @CustomCoding(OmitEmpty<[Table]>.self) @CodingKey("tableFiles") var tables: [Table]
    @CustomCoding(OmitEmpty<[B2S]>.self) @CodingKey("b2sFiles") var backglasses: [B2S]
    @CustomCoding(OmitEmpty<[Tutorial]>.self) @CodingKey("tutorialFiles") var tutorials: [Tutorial]
    @CustomCoding(OmitEmpty<[ROM]>.self) @CodingKey("romFiles") var roms: [ROM]
    @CustomCoding(OmitEmpty<[PupPack]>.self) @CodingKey("pupPackFiles") var pupPacks: [PupPack]
    @CustomCoding(OmitEmpty<[AltColors]>.self) @CodingKey("altColorFiles") var altColors:
        [AltColors]
    @CustomCoding(OmitEmpty<[AltSound]>.self) @CodingKey("altSoundFiles") var altSounds: [AltSound]
    @CustomCoding(OmitEmpty<[POV]>.self) @CodingKey("povFiles") var povs: [POV]
    @CustomCoding(OmitEmpty<[WheelArt]>.self) @CodingKey("wheelArtFiles") var wheels: [WheelArt]
    @CustomCoding(OmitEmpty<[Topper]>.self) @CodingKey("topperFiles") var toppers: [Topper]
    @CustomCoding(OmitEmpty<[MediaPack]>.self) @CodingKey("mediaPackFiles") var mediaPacks:
        [MediaPack]
    @CustomCoding(OmitEmpty<[Rules]>.self) @CodingKey("ruleFiles") var rules: [Rules]

    @CustomCoding(OmitIfFalse.self)
    var broken: Bool

    var gameId: String { id }
    var gameName: String { name }

    var url: URL? { nil }
    @CustomCoding(OmitEmpty<[URL]>.self) var urls: [URL]
    var version: String? { nil }

    var ipdbId: String? {
        // https://www.ipdb.org/machine.cgi?id=1654
        ipdbUrl?.query()?.split(separator: "=").last?.description
    }

    var shouldHaveIPDBEntry: Bool {
        manufacturer.shouldHaveIPDBEntry
    }

    subscript(kind: GameResourceKind) -> [any GameResource] {
        switch kind {
        case .game: []
        case .table: tables
        case .b2s: backglasses
        case .tutorial: tutorials
        case .rom: roms
        case .pupPack: pupPacks
        case .altColor: altColors
        case .altSound: altSounds
        case .pov: povs
        case .wheelArt: wheels
        case .topper: toppers
        case .mediaPack: mediaPacks
        case .rule: rules
        }
    }

    var description: String {
        "\(self.name) \(self.manufacturer) (\(self.year ?? 0))"
    }
}

extension Game: Comparable {
    static func < (lhs: Game, rhs: Game) -> Bool {
        lhs.name < rhs.name
    }

    static func == (lhs: Game, rhs: Game) -> Bool {
        lhs.id == rhs.id
    }
}

enum GameResourceKind: String, Codable, Sendable {
    case game
    case table
    case b2s
    case tutorial
    case rom
    case pupPack
    case altColor
    case altSound
    case pov
    case wheelArt
    case topper
    case mediaPack
    case rule
}
