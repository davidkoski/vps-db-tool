import Foundation
import ReerCodable

@Codable
struct GameResourceCommon: Sendable {
    @CustomCoding(OmitDateUnixEpoch.self) var createdAt: Date
    @CustomCoding(OmitDateUnixEpoch.self) var updatedAt: Date

    var comment: String?

    @CustomCoding(OmitGameRef.self) var game: GameRef
    @CustomCoding(OmitEmpty<[Resource]>.self) var urls: [Resource]
    @CustomCoding(OmitEmpty<[Author]>.self) var authors: [Author]
    var version: String?
}

protocol GameResource: Metadata {
    var gameResource: GameResourceCommon { get set }
}

extension GameResource {
    var version: String? {
        gameResource.version
    }

    var url: URL? {
        gameResource.urls.first?.url
    }

    var urls: [URL] {
        gameResource.urls.map { $0.url }
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

struct GameResourceCommonTransformer: CodingCustomizable {

    static func decode(by decoder: any Decoder, keys: [String]) throws -> GameResourceCommon {
        try GameResourceCommon(from: decoder)
    }

    static func encode(by encoder: any Encoder, key: String, value: GameResourceCommon) throws {
        try value.encode(to: encoder)
    }

}

struct OmitGameRef: CodingCustomizable {

    static func decode(by decoder: any Decoder, keys: [String]) throws -> GameRef {
        let container = try decoder.container(keyedBy: AnyCodingKey.self)

        var found = false
        for key in keys {
            guard let key = AnyCodingKey(stringValue: key) else { continue }
            if container.contains(key) {
                found = true
                break
            }
        }

        if found {
            return try container.decode(type: GameRef.self, keys: keys)
        }

        return GameRef(id: "", name: "")
    }

    static func encode(by encoder: any Encoder, key: String, value: GameRef) throws {
        if !value.id.isEmpty {
            try value.encode(to: encoder)
        }
    }

}
