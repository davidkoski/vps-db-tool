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

extension GameResourceCommon {
    /// Common fields for a new resource built from a scanned detail page.
    public init(detail: DetailResult, game: Game, db: Database, comment: String? = nil) {
        self.init(
            createdAt: detail.resolvedDate,
            updatedAt: Date(),
            comment: comment,
            game: GameRef(game: game),
            urls: [Resource(url: detail.normalizedURL, broken: false)],
            authors: [db.matchAuthor(name: detail.author)],
            version: canonicalVersion(detail.version)
        )
    }
}

public protocol GameResource: Metadata, Equatable {
    var gameResource: GameResourceCommon { get set }
    var kind: GameResourceKind { get }
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

    func matchAuthor(_ name: String) -> Author? {
        gameResource.authors.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }
}

public enum MergeURLAction: Sendable, Equatable {
    case add
    case replace(URL)
}

extension GameResource {

    func shouldMerge(normalizedURL: URL, canonicalAuthor: String) -> MergeURLAction? {
        let resourceFirstAuthor = canonicalizeAuthor(gameResource.authors.first?.name)
        if canonicalAuthor != resourceFirstAuthor { return nil }

        let site = Site(normalizedURL)
        for url in urls {
            if url == normalizedURL {
                // we already have it
                return nil
            }
            if Site(url) == site {
                // offer to replace
                return .replace(url)
            }
        }

        return .add
    }

    @discardableResult
    mutating public func mergeURL(other: any GameResource) -> MergeURLAction? {
        guard let url = other.url else { return nil }
        let site = Site(url)

        var replaced: URL?
        gameResource.urls = gameResource.urls.map {
            if Site($0.url) == site {
                replaced = $0.url
                return .init(url: url, broken: false)
            } else {
                return $0
            }
        }

        if replaced == nil {
            gameResource.urls.append(.init(url: url, broken: false))
        }

        if other.createdAt > self.createdAt {
            self.gameResource.createdAt = other.createdAt
        }
        if let version = other.version {
            self.gameResource.version = version
        }
        self.gameResource.updatedAt = Date()

        if let replaced {
            return .replace(replaced)
        } else {
            return .add
        }
    }

}

extension Array where Element: GameResource {

    func matchAuthor(_ name: String) -> Author? {
        for item in self {
            if let author = item.matchAuthor(name) {
                return author
            }
        }
        return nil
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
            return try container.decode(type: GameRef.self, keys: keys.map { AnyCodingKey($0) })
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
