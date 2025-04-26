import Foundation
import HelperCoders
import MetaCodable

protocol Metadata {
    var id: String { get }
    var createdAt: Date { get }
    var updatedAt: Date { get }
    var gameId: String { get }
    var gameName: String { get }
    var url: URL? { get }
}

@Codable
struct GameResourceCommon: Sendable {
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

protocol GameResource: Metadata {
    var gameResource: GameResourceCommon { get set }
}

extension GameResource {
    var url: URL? {
        gameResource.urls.first?.url
    }

    var createdAt: Date {
        gameResource.createdAt
    }

    var updatedAt: Date {
        gameResource.updatedAt
    }

    var gameId: String {
        gameResource.game.id
    }

    var gameName: String {
        gameResource.game.name
    }

}

@Codable
struct Resource: Sendable {
    let url: URL
    @Default(false) let broken: Bool
}

@Codable
struct GameRef: Sendable {
    let id: String
    let name: String
}

@Codable
struct Table: GameResource, Sendable {
    let id: String

    @CodedAt
    var gameResource: GameResourceCommon

    @Default(ifMissing: []) let features: Set<TableFeature>
    @Default<TableFormat?>(nil) let tableFormat: TableFormat?
    let edition: String?

    @Default<URL?>(nil)
    let imgUrl: URL?
}

@Codable
struct B2S: GameResource, Sendable {
    // Note: b2s for FX tables don't have an id
    @Default(ifMissing: UUID().uuidString)
    let id: String

    @CodedAt
    var gameResource: GameResourceCommon

    @Default(ifMissing: []) let features: Set<B2SFeature>?
    let imgUrl: URL?
}

@Codable
struct Tutorial: GameResource, Sendable {
    let id: String

    @CodedAt
    var gameResource: GameResourceCommon

    let youtubeId: String
    let title: String
}

@Codable
struct ROM: GameResource, Sendable {
    let id: String

    @CodedAt
    var gameResource: GameResourceCommon
}

@Codable
struct PupPack: GameResource, Sendable {
    let id: String

    @CodedAt
    var gameResource: GameResourceCommon
}

@Codable
struct AltColors: GameResource, Sendable {
    let id: String

    @CodedAt
    var gameResource: GameResourceCommon
}

@Codable
struct AltSound: GameResource, Sendable {
    let id: String

    @CodedAt
    var gameResource: GameResourceCommon
}

@Codable
struct POV: GameResource, Sendable {
    let id: String

    @CodedAt
    var gameResource: GameResourceCommon
}

@Codable
struct WheelArt: GameResource, Sendable {
    let id: String

    @CodedAt
    var gameResource: GameResourceCommon
}

@Codable
struct Topper: GameResource, Sendable {
    let id: String

    @CodedAt
    var gameResource: GameResourceCommon
}

@Codable
struct MediaPack: GameResource, Sendable {
    let id: String

    @CodedAt
    var gameResource: GameResourceCommon
}

@Codable
struct Rules: GameResource, Sendable {
    let id: String

    @CodedAt
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
struct Game: Metadata, Sendable {
    let id: String

    @CodedBy(Since1970DateCoder()) @Default(ifMissing: Date())
    let createdAt: Date
    @CodedBy(Since1970DateCoder()) @Default(ifMissing: Date())
    let updatedAt: Date

    let name: String
    let manufacturer: String
    let imageUrl: URL?

    @CodedAt("MPU") let mpu: String?
    let year: Int?

    @Default(ifMissing: []) let theme: Set<Theme>

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

    var gameId: String { id }
    var gameName: String { name }
    var url: URL? { nil }

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
