import Collections
import Foundation
import ReerCodable

func canonicalVersion(_ string: String?) -> String {
    (string ?? "")
        .replacingOccurrences(of: "v", with: "")
        .replacingOccurrences(of: " ", with: "")
        .replacingOccurrences(of: ".0.0", with: ".0")
        .replacing(/.0$/, with: { _ in "" })
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
struct Resource: Sendable, Codable, Equatable {
    var url: URL

    @CustomCoding(OmitIfFalse.self)
    var broken: Bool
}

@Codable
struct GameRef: Sendable, Equatable {
    let id: String
    let name: String

    init(game: Game) {
        self.id = game.id
        self.name = game.name
    }
}

@Codable
struct Table: GameResource, Sendable {
    let id: String

    @CustomCoding(GameResourceCommonTransformer.self)
    var gameResource: GameResourceCommon

    @CustomCoding(OmitEmpty<OrderedSet<TableFeature>>.self) var features: OrderedSet<TableFeature>
    var tableFormat: TableFormat?
    var edition: String?

    var gameFileName: String?

    var imgUrl: URL?
}

@Codable
struct B2S: GameResource, Sendable {
    // Note: b2s for FX tables don't have an id
    var id: String = newId()

    @CustomCoding(OmitEmpty<OrderedSet<B2SFeature>>.self) let features: OrderedSet<B2SFeature>

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

    var fileName: String?
    var folder: String?
    var type: String?
}

@Codable
struct AltSound: GameResource, Sendable {
    let id: String

    @CustomCoding(GameResourceCommonTransformer.self)
    var gameResource: GameResourceCommon
}

@Codable
struct Sound: GameResource, Sendable {
    // Note: these are largely missing -- sound files look obsolete
    var id: String = newId()

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

struct IPDBURL: CodingCustomizable {

    static func decode(by decoder: any Decoder, keys: [String]) throws -> URL? {
        let url: URL? = try decoder.valueIfPresent(forKeys: keys)
        if url?.path() == "Not%20Available" {
            return nil
        } else {
            return url
        }
    }

    static func encode(by encoder: any Encoder, key: String, value: URL?) throws {
        if value != nil {
            var container = encoder.container(keyedBy: AnyCodingKey.self)
            try container.encode(value, forKey: .init(key))
        }
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

    @CodingKey("MPU") var mpu: String?
    var year: Int?

    @CustomCoding(OmitEmpty<OrderedSet<Theme>>.self) var theme: OrderedSet<Theme>

    // empty designers array is still emitted (usually)
    var designers: OrderedSet<String> = []

    var type: Kind?
    var players: Int?

    @CustomCoding(IPDBURL.self)
    var ipdbUrl: URL?
    var imgUrl: URL?

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

    // these are semi-disabled
    @CustomCoding(OmitEmpty<[Sound]>.self) @CodingKey("soundFiles") var sounds: [Sound]

    var broken: Bool = false

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
        case .sound: sounds
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
}

enum GameResourceKind: String, Codable, Sendable, Comparable {
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
    case sound

    var sortOrder: Int {
        switch self {
        case .game: 0
        case .table: 1
        case .b2s: 2
        case .tutorial: 3
        case .rom: 4
        case .pupPack: 5
        case .altColor: 6
        case .altSound: 7
        case .pov: 8
        case .wheelArt: 9
        case .topper: 10
        case .mediaPack: 11
        case .rule: 12
        case .sound: 13
        }
    }

    static func < (lhs: GameResourceKind, rhs: GameResourceKind) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}
