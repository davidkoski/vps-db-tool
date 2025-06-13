import Foundation
import ReerCodable

@Codable
public struct GameResourceCommon: Sendable, Equatable {
    @CustomCoding(OmitDateUnixEpoch.self) public var createdAt: Date
    @CustomCoding(OmitDateUnixEpoch.self) public var updatedAt: Date

    public var comment: String?

    @CustomCoding(OmitGameRef.self) public var game: GameRef
    @CustomCoding(OmitEmpty<[Resource]>.self) public var urls: [Resource]
    @CustomCoding(OmitEmpty<[Author]>.self) public var authors: [Author]
    public var version: String?
}

public protocol GameResource: Metadata, Equatable {
    var gameResource: GameResourceCommon { get set }
}

extension GameResource {
    public var version: String? {
        gameResource.version
    }

    public var url: URL? {
        gameResource.urls.first?.url
    }

    public var urls: [URL] {
        gameResource.urls.map { $0.url }
    }

    public var createdAt: Date {
        gameResource.createdAt
    }

    public var updatedAt: Date {
        gameResource.updatedAt
    }

    public var gameId: String {
        gameResource.game.id
    }

    public var gameName: String {
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
            var container = encoder.container(keyedBy: AnyCodingKey.self)
            try container.encode(value, forKey: .init(key))
        }
    }

}
