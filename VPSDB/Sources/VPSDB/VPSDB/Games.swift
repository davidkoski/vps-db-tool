import Collections
import Foundation
import OrderedCollections
import ReerCodable

public func canonicalVersion(_ string: String?) -> String {
    (string ?? "")
        .replacingOccurrences(of: "Version", with: "")
        .replacingOccurrences(of: "FizX3.3", with: "")
        .replacingOccurrences(of: "v", with: "")
        .replacingOccurrences(of: "V", with: "")
        .replacingOccurrences(of: " ", with: "")
        .replacing(/[.]0+$/, with: { _ in "" })
        .replacing(/[.]0+$/, with: { _ in "" })
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

public let imageBase = URL(string: "https://virtualpinballspreadsheet.github.io/vps-db/img")!

@Codable
public struct Table: GameResource, Sendable {
    public var id: String

    @CustomCoding(GameResourceCommonTransformer.self)
    public var gameResource: GameResourceCommon

    public var parentId: String?

    @CustomCoding(OmitEmpty<OrderedSet<TableFeature>>.self) public var features:
        OrderedSet<TableFeature>
    public var tableFormat: TableFormat?
    public var edition: String?

    public var gameFileName: String?

    public var imgUrl: URL?

    public var kind: GameResourceKind { .table }

    /// New table from a scanned page -- features are scanned from the text.
    /// `imgUrl` is left for the image processing (crop / upload).
    public init(detail: DetailResult, game: Game, db: Database) {
        let scanned = TableFeature.scan(detail.text)
        self.init(
            id: newId(),
            gameResource: .init(
                detail: detail, game: game, db: db,
                comment: scanTableText(detail.name, detail.text)),
            parentId: nil,
            features: OrderedSet(TableFeature.allCases.filter { scanned.contains($0) }),
            tableFormat: nil,
            edition: nil,
            gameFileName: nil,
            imgUrl: nil)
    }

    public func hasFeature(_ feature: TableFeature) -> Bool {
        features.contains(feature)
    }

    /// Add / remove a feature, keeping the features in canonical (`allCases`) order.
    public mutating func setFeature(_ feature: TableFeature, _ on: Bool) {
        var set = Set(features)
        if on {
            set.insert(feature)
        } else {
            set.remove(feature)
        }
        features = OrderedSet(TableFeature.allCases.filter { set.contains($0) })
    }
}

@Codable
public struct B2S: GameResource, Sendable {
    // Note: b2s for FX tables don't have an id
    public var id: String = newId()

    @CustomCoding(OmitEmpty<OrderedSet<B2SFeature>>.self) public var features:
        OrderedSet<B2SFeature>

    @CustomCoding(GameResourceCommonTransformer.self)
    public var gameResource: GameResourceCommon

    public var imgUrl: URL?

    public var kind: GameResourceKind { .b2s }

    /// New backglass from a scanned page -- features are scanned from the text.
    /// `imgUrl` is left for the image processing (crop / upload).
    public init(detail: DetailResult, game: Game, db: Database) {
        let scanned = B2SFeature.scan(detail.text)
        self.init(
            id: newId(),
            features: OrderedSet(B2SFeature.allCases.filter { scanned.contains($0) }),
            gameResource: .init(
                detail: detail, game: game, db: db,
                comment: scanB2Text(detail.name, detail.text)),
            imgUrl: nil)
    }

    public func hasFeature(_ feature: B2SFeature) -> Bool {
        features.contains(feature)
    }

    /// Add / remove a feature, keeping the features in canonical (`allCases`) order.
    public mutating func setFeature(_ feature: B2SFeature, _ on: Bool) {
        var set = Set(features)
        if on {
            set.insert(feature)
        } else {
            set.remove(feature)
        }
        features = OrderedSet(B2SFeature.allCases.filter { set.contains($0) })
    }
}

@Codable
public struct Tutorial: GameResource, Sendable {
    public var id: String

    @CustomCoding(GameResourceCommonTransformer.self)
    public var gameResource: GameResourceCommon

    public var youtubeId: String?
    public var url: URL?
    public var title: String

    public var urls: [URL] {
        // the url property is used rather than the list of urls
        [url].compactMap { $0 }
    }

    public var kind: GameResourceKind { .tutorial }

    /// New tutorial from a scanned page.
    ///
    /// YouTube videos are stored by `youtubeId` (with the watch url in the
    /// common urls), anything else in `url`.
    public init(detail: DetailResult, game: Game, db: Database) {
        var common = GameResourceCommon(detail: detail, game: game, db: db)

        // we don't store anything in the common urls
        common.urls = []
        common.version = nil

        // tutorials aren't versioned
        common.version = nil

        let youtubeId = youtubeVideoId(detail.url)
        self.init(
            id: newId(), gameResource: common, youtubeId: youtubeId,
            url: youtubeId == nil ? detail.url : nil,
            title: detail.name)
    }
}

@Codable
public struct ROM: GameResource, Sendable {
    public var id: String

    @CustomCoding(GameResourceCommonTransformer.self)
    public var gameResource: GameResourceCommon

    public var kind: GameResourceKind { .rom }

    /// The version of a ROM is its name, e.g. `amh_022` -- taken from the
    /// first zip file name (`amh_022.zip`) mentioned in the detail text.
    public init(detail: DetailResult, game: Game, db: Database) {
        var common = GameResourceCommon(detail: detail, game: game, db: db)
        if let name = scanROMName(detail.text) {
            common.version = name
        }
        self.init(id: newId(), gameResource: common)
    }
}

@Codable
public struct PupPack: GameResource, Sendable {
    public var id: String

    @CustomCoding(GameResourceCommonTransformer.self)
    public var gameResource: GameResourceCommon

    public var kind: GameResourceKind { .pupPack }

    public init(detail: DetailResult, game: Game, db: Database) {
        self.init(id: newId(), gameResource: .init(detail: detail, game: game, db: db))
    }
}

@Codable
public struct AltColors: GameResource, Sendable {
    public var id: String

    @CustomCoding(GameResourceCommonTransformer.self)
    public var gameResource: GameResourceCommon

    public var fileName: String?
    public var folder: String?
    public var type: String?

    public var kind: GameResourceKind { .altColor }

    /// New alt color from a scanned page -- the folder defaults to the game's
    /// (first) ROM name, e.g. `mm_109c`.
    public init(detail: DetailResult, game: Game, db: Database) {
        self.init(
            id: newId(),
            gameResource: .init(detail: detail, game: game, db: db),
            fileName: nil,
            folder: game.roms.first?.version,
            type: nil)
    }
}

@Codable
public struct AltSound: GameResource, Sendable {
    public var id: String

    @CustomCoding(GameResourceCommonTransformer.self)
    public var gameResource: GameResourceCommon

    public var kind: GameResourceKind { .altSound }

    public init(detail: DetailResult, game: Game, db: Database) {
        self.init(id: newId(), gameResource: .init(detail: detail, game: game, db: db))
    }
}

@Codable
public struct Sound: GameResource, Sendable {
    // Note: these are largely missing -- sound files look obsolete
    public var id: String = newId()

    public var kind: GameResourceKind { .sound }

    @CustomCoding(GameResourceCommonTransformer.self)
    public var gameResource: GameResourceCommon
}

@Codable
public struct POV: GameResource, Sendable {
    public var id: String

    @CustomCoding(GameResourceCommonTransformer.self)
    public var gameResource: GameResourceCommon

    public var kind: GameResourceKind { .pov }

    public init(detail: DetailResult, game: Game, db: Database) {
        self.init(
            id: newId(),
            gameResource: .init(
                detail: detail, game: game, db: db,
                comment: scanPOVText(detail.name, detail.text)))
    }
}

@Codable
public struct WheelArt: GameResource, Sendable {
    public var id: String

    @CustomCoding(GameResourceCommonTransformer.self)
    public var gameResource: GameResourceCommon

    public var kind: GameResourceKind { .wheelArt }

    public init(detail: DetailResult, game: Game, db: Database) {
        self.init(
            id: newId(),
            gameResource: .init(
                detail: detail, game: game, db: db,
                comment: scanWheelText(detail.name, detail.text)))
    }
}

@Codable
public struct Topper: GameResource, Sendable {
    public var id: String

    @CustomCoding(GameResourceCommonTransformer.self)
    public var gameResource: GameResourceCommon

    public var kind: GameResourceKind { .topper }

    public init(detail: DetailResult, game: Game, db: Database) {
        self.init(id: newId(), gameResource: .init(detail: detail, game: game, db: db))
    }
}

@Codable
public struct MediaPack: GameResource, Sendable {
    public var id: String

    @CustomCoding(GameResourceCommonTransformer.self)
    public var gameResource: GameResourceCommon

    public var kind: GameResourceKind { .mediaPack }

    public init(detail: DetailResult, game: Game, db: Database) {
        self.init(id: newId(), gameResource: .init(detail: detail, game: game, db: db))
    }
}

@Codable
public struct Rules: GameResource, Sendable {
    public var id: String

    @CustomCoding(GameResourceCommonTransformer.self)
    public var gameResource: GameResourceCommon

    public var kind: GameResourceKind { .rule }

    public init(detail: DetailResult, game: Game, db: Database) {
        self.init(
            id: newId(),
            gameResource: .init(
                detail: detail, game: game, db: db,
                comment: scanRuleText(detail.name, detail.text)))
    }
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
            func connect<T: GameResource>(_ game: inout Game, _ keyPath: WritableKeyPath<Game, [T]>)
            {
                let id = GameRef(id: game.id, name: game.name)
                game[keyPath: keyPath] = game[keyPath: keyPath].map { i in
                    var i = i
                    i.gameResource.game = id
                    return i
                }
            }

            var game = try Game(from: decoder)

            connect(&game, \.tables)
            connect(&game, \.backglasses)
            connect(&game, \.tutorials)
            connect(&game, \.roms)
            connect(&game, \.pupPacks)
            connect(&game, \.altColors)
            connect(&game, \.altSounds)
            connect(&game, \.sounds)
            connect(&game, \.povs)
            connect(&game, \.wheels)
            connect(&game, \.toppers)
            connect(&game, \.mediaPacks)
            connect(&game, \.rules)

            self.game = game
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
public struct Game: Metadata, Identifiable, Sendable, CustomStringConvertible {

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

    public func matches(_ query: String) -> Bool {
        gameId == query || gameName.lowercased().contains(query)
            || manufacturer.rawValue.lowercased().contains(query)
            || (year?.description ?? "").contains(query)
            || designers.contains { $0.lowercased().contains(query) }
            || theme.contains { $0.rawValue.lowercased().contains(query) }
            || tables.contains {
                ($0.gameResource.authors.first?.name.lowercased() ?? "").contains(query)
            }
    }

    func matchAuthor(_ name: String) -> Author? {
        func match(_ array: [any GameResource]) -> Author? {
            for item in array {
                if let author = item.matchAuthor(name) {
                    return author
                }
            }
            return nil
        }

        let probe: [[any GameResource]] = [
            tables, backglasses, tutorials, wheels, pupPacks,
            altColors, altSounds, povs, roms,
        ]

        for item in probe {
            if let author = match(item) {
                return author
            }
        }

        return nil
    }

    func collect(authors set: inout Set<String>) {
        func collect(_ array: [any GameResource]) {
            for item in array {
                set.formUnion(item.gameResource.authors.map { $0.name })
            }
        }

        collect(tables)
        collect(backglasses)
        collect(tutorials)
        collect(roms)
        collect(pupPacks)
        collect(altColors)
        collect(altSounds)
        collect(povs)
        collect(wheels)
    }

    public func shouldMergeURL<T: GameResource>(_ item: T) -> T? {
        guard let firstAuthor = item.gameResource.authors.first else { return nil }
        guard let url = item.url else { return nil }

        let targetSites: Set<Site> =
            switch Site(url) {
            case .vpf: [.vpu, .pinballnirvana]
            case .vpu: [.vpf, .pinballnirvana]
            case .pinballnirvana: [.vpu, .vpf]
            default: []
            }

        if targetSites.isEmpty { return nil }

        return self[item.kind].first {
            if $0.gameResource.authors.first == firstAuthor {
                let url = $0.url
                if let site = Site(url), targetSites.contains(site) {
                    return true
                }
            }
            return false
        } as? T
    }

    public subscript(kind: GameResourceKind) -> [any GameResource] {
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

extension Game {
    /// Replace the resource with the same id at `keyPath`, or append it if not present.
    public mutating func upsert<R: GameResource>(
        _ resource: R, at keyPath: WritableKeyPath<Game, [R]>
    ) {
        if let index = self[keyPath: keyPath].firstIndex(where: { $0.id == resource.id }) {
            self[keyPath: keyPath][index] = resource
        } else {
            self[keyPath: keyPath].append(resource)
        }
    }
}

extension Game {
    /// A new game, not yet in the database.
    public init(
        name: String,
        manufacturer: Manufacturer = .unknown,
        year: Int? = nil,
        type: Kind? = nil,
        players: Int? = nil,
        ipdbUrl: URL? = nil,
        designers: [String] = [],
        themes: [Theme] = []
    ) {
        let now = Date()
        self.init(
            id: newId(10),
            createdAt: now,
            updatedAt: now,
            lastCreatedAt: now,
            name: name,
            manufacturer: manufacturer,
            imageUrl: nil,
            mpu: nil,
            year: year,
            theme: OrderedSet(themes),
            designers: OrderedSet(designers),
            type: type,
            players: players,
            ipdbUrl: ipdbUrl,
            imgUrl: nil,
            tables: [],
            backglasses: [],
            tutorials: [],
            roms: [],
            pupPacks: [],
            altColors: [],
            altSounds: [],
            povs: [],
            wheels: [],
            toppers: [],
            mediaPacks: [],
            rules: [],
            sounds: [],
            broken: false,
            urls: []
        )
    }
}

extension Game: Comparable {
    static public func < (lhs: Game, rhs: Game) -> Bool {
        if lhs.name != rhs.name {
            lhs.name < rhs.name
        } else if let y1 = lhs.year, let y2 = rhs.year, y1 != y2 {
            y1 < y2
        } else {
            lhs.id < rhs.id
        }
    }
}

public enum GameResourceKind: String, Codable, Sendable, Comparable, CaseIterable {
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
