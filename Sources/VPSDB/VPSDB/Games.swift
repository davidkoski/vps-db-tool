import Collections
import Foundation
import ReerCodable

public func canonicalVersion(_ string: String?) -> String {
    (string ?? "")
        .replacingOccurrences(of: "v", with: "")
        .replacingOccurrences(of: " ", with: "")
        .replacingOccurrences(of: ".0.0", with: ".0")
        .replacing(/.0$/, with: { _ in "" })
}

public protocol Metadata {
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
public struct Resource: Sendable, Codable, Equatable {
    public var url: URL

    @CustomCoding(OmitIfFalse.self)
    public var broken: Bool
}

@Codable
public struct GameRef: Sendable, Equatable {
    public let id: String
    public let name: String

    public init(game: Game) {
        self.id = game.id
        self.name = game.name
    }
}

@Codable
public struct Table: GameResource, Sendable {
    public let id: String

    @CustomCoding(GameResourceCommonTransformer.self)
    public var gameResource: GameResourceCommon

    @CustomCoding(OmitEmpty<OrderedSet<TableFeature>>.self) public var features:
        OrderedSet<TableFeature>
    public var tableFormat: TableFormat?
    public var edition: String?

    public var gameFileName: String?

    public var imgUrl: URL?
}

@Codable
public struct B2S: GameResource, Sendable {
    // Note: b2s for FX tables don't have an id
    public var id: String = newId()

    @CustomCoding(OmitEmpty<OrderedSet<B2SFeature>>.self) let features: OrderedSet<B2SFeature>

    @CustomCoding(GameResourceCommonTransformer.self)
    public var gameResource: GameResourceCommon

    public var imgUrl: URL?
}

@Codable
public struct Tutorial: GameResource, Sendable {
    public let id: String

    @CustomCoding(GameResourceCommonTransformer.self)
    public var gameResource: GameResourceCommon

    public var youtubeId: String
    public var title: String
}

@Codable
public struct ROM: GameResource, Sendable {
    public let id: String

    @CustomCoding(GameResourceCommonTransformer.self)
    public var gameResource: GameResourceCommon
}

@Codable
public struct PupPack: GameResource, Sendable {
    public let id: String

    @CustomCoding(GameResourceCommonTransformer.self)
    public var gameResource: GameResourceCommon
}

@Codable
public struct AltColors: GameResource, Sendable {
    public let id: String

    @CustomCoding(GameResourceCommonTransformer.self)
    public var gameResource: GameResourceCommon

    public var fileName: String?
    public var folder: String?
    public var type: String?
}

@Codable
public struct AltSound: GameResource, Sendable {
    public let id: String

    @CustomCoding(GameResourceCommonTransformer.self)
    public var gameResource: GameResourceCommon
}

@Codable
public struct Sound: GameResource, Sendable {
    // Note: these are largely missing -- sound files look obsolete
    public var id: String = newId()

    @CustomCoding(GameResourceCommonTransformer.self)
    public var gameResource: GameResourceCommon
}

@Codable
public struct POV: GameResource, Sendable {
    public let id: String

    @CustomCoding(GameResourceCommonTransformer.self)
    public var gameResource: GameResourceCommon
}

@Codable
public struct WheelArt: GameResource, Sendable {
    public let id: String

    @CustomCoding(GameResourceCommonTransformer.self)
    public var gameResource: GameResourceCommon
}

@Codable
public struct Topper: GameResource, Sendable {
    public let id: String

    @CustomCoding(GameResourceCommonTransformer.self)
    public var gameResource: GameResourceCommon
}

@Codable
public struct MediaPack: GameResource, Sendable {
    public let id: String

    @CustomCoding(GameResourceCommonTransformer.self)
    public var gameResource: GameResourceCommon
}

@Codable
public struct Rules: GameResource, Sendable {
    public let id: String

    @CustomCoding(GameResourceCommonTransformer.self)
    public var gameResource: GameResourceCommon
}

public struct GameDecodeError: Error {
    public let id: String
    public let name: String
    public let error: Error
}

/// container to help find errors in decoding
public struct GameContainer: Decodable {
    public let game: Game

    public init(from decoder: any Decoder) throws {
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

public struct IPDBURL: CodingCustomizable {

    static public func decode(by decoder: any Decoder, keys: [String]) throws -> URL? {
        let url: URL? = try decoder.valueIfPresent(forKeys: keys)
        if url?.path() == "Not%20Available" {
            return nil
        } else {
            return url
        }
    }

    static public func encode(by encoder: any Encoder, key: String, value: URL?) throws {
        if value != nil {
            var container = encoder.container(keyedBy: AnyCodingKey.self)
            try container.encode(value, forKey: .init(key))
        }
    }

}

@Codable
public struct Game: Metadata, Sendable, CustomStringConvertible {

    public let id: String

    @CustomCoding(OmitDateUnixEpoch.self) public var createdAt: Date
    @CustomCoding(OmitDateUnixEpoch.self) public var updatedAt: Date

    @CustomCoding(OmitDateUnixEpoch.self) public var lastCreatedAt: Date

    public var name: String
    public var manufacturer: Manufacturer
    public var imageUrl: URL?

    @CodingKey("MPU") public var mpu: String?
    public var year: Int?

    @CustomCoding(OmitEmpty<OrderedSet<Theme>>.self) public var theme: OrderedSet<Theme>

    // empty designers array is still emitted (usually)
    public var designers: OrderedSet<String> = []

    public var type: Kind?
    public var players: Int?

    @CustomCoding(IPDBURL.self)
    public var ipdbUrl: URL?
    public var imgUrl: URL?

    @CustomCoding(OmitEmpty<[Table]>.self) @CodingKey("tableFiles") public var tables: [Table]
    @CustomCoding(OmitEmpty<[B2S]>.self) @CodingKey("b2sFiles") public var backglasses: [B2S]
    @CustomCoding(OmitEmpty<[Tutorial]>.self) @CodingKey("tutorialFiles") public var tutorials:
        [Tutorial]
    @CustomCoding(OmitEmpty<[ROM]>.self) @CodingKey("romFiles") public var roms: [ROM]
    @CustomCoding(OmitEmpty<[PupPack]>.self) @CodingKey("pupPackFiles") public var pupPacks:
        [PupPack]
    @CustomCoding(OmitEmpty<[AltColors]>.self) @CodingKey("altColorFiles") public var altColors:
        [AltColors]
    @CustomCoding(OmitEmpty<[AltSound]>.self) @CodingKey("altSoundFiles") public var altSounds:
        [AltSound]
    @CustomCoding(OmitEmpty<[POV]>.self) @CodingKey("povFiles") public var povs: [POV]
    @CustomCoding(OmitEmpty<[WheelArt]>.self) @CodingKey("wheelArtFiles") public var wheels:
        [WheelArt]
    @CustomCoding(OmitEmpty<[Topper]>.self) @CodingKey("topperFiles") public var toppers: [Topper]
    @CustomCoding(OmitEmpty<[MediaPack]>.self) @CodingKey("mediaPackFiles") public var mediaPacks:
        [MediaPack]
    @CustomCoding(OmitEmpty<[Rules]>.self) @CodingKey("ruleFiles") public var rules: [Rules]

    // these are semi-disabled
    @CustomCoding(OmitEmpty<[Sound]>.self) @CodingKey("soundFiles") public var sounds: [Sound]

    public var broken: Bool = false

    public var gameId: String { id }
    public var gameName: String { name }

    public var url: URL? { nil }
    @CustomCoding(OmitEmpty<[URL]>.self) public var urls: [URL]
    public var version: String? { nil }

    public var ipdbId: String? {
        // https://www.ipdb.org/machine.cgi?id=1654
        ipdbUrl?.query()?.split(separator: "=").last?.description
    }

    public var shouldHaveIPDBEntry: Bool {
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

    public var description: String {
        "\(self.name) \(self.manufacturer) (\(self.year ?? 0))"
    }
}

extension Game: Comparable {
    static public func < (lhs: Game, rhs: Game) -> Bool {
        lhs.name < rhs.name
    }
}

public enum GameResourceKind: String, Codable, Sendable, Comparable {
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

    public var sortOrder: Int {
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

    public static func < (lhs: GameResourceKind, rhs: GameResourceKind) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}
