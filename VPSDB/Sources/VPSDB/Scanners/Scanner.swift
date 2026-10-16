import Foundation
import Logging
import ReerCodable

private let log = Logger(label: "Scanner")

public enum ScanError: Error {
    case unableToScanDetail(URL)
    case scannerNotAvailable(URL)
}

public protocol ScanSources {
    func sources(kind: GameResourceKind) -> [URL]
    func update(kind: GameResourceKind, url: URL, page: Int) -> URL?
}

public protocol DetailScanner: Sendable {
    var version: Int { get }
    func scanDetail(request: DetailScanRequest, content: String) async throws -> DetailResult?
}

public protocol ListScanner: Sendable {
    var version: Int { get }
    func scanList(request: ListScanRequest, content: String) async throws -> ListResult
}

public protocol ScanRequest: Sendable {
    var site: Site { get }
    var url: URL { get }
    var kind: GameResourceKind { get }
}

public struct DetailScanRequest: ScanRequest {
    public let site: Site
    public let url: URL
    public let canonicalURL: URL
    public let kind: GameResourceKind
    public let scannerVersion: Int
    public let updated: DetailResult.DateKind

    public static func test(_ kind: GameResourceKind) -> Self {
        .init(URL(string: "http://www.vpuniverse.com")!, kind)
    }

    public init(_ url: URL, _ kind: GameResourceKind, updated: DetailResult.DateKind = .unknown) {
        self.site = Site(url)
        self.url = url
        self.canonicalURL = site.canonicalize(url)
        self.kind = kind
        self.scannerVersion = site.detailScanner.version
        self.updated = updated
    }

    public func scan(content: String) async throws -> DetailResult? {
        try await site.scanner?.scanDetail(request: self, content: content)
    }

    public func fetch(
        client: HTTPClient, maxAge: Duration = .seconds(3600), scanCache: ScanCache?
    ) async throws -> DetailResult {
        if let cached = await scanCache?.get(request: self),
            cached.detailKind == .detail,
            cached.date.isValid(updated)
        {
            return cached
        }

        log.info("Download \(url)")
        let content = try await client.getString(url, maxAge: maxAge)
        guard let result = try await scan(content: content) else {
            throw ScanError.unableToScanDetail(url)
        }
        await scanCache?.cache(request: self, item: result)
        return result
    }
}

public struct ListScanRequest: ScanRequest, Hashable {
    public let site: Site
    public let base: URL
    public let url: URL
    public let page: Int
    public let kind: GameResourceKind
    public let scannerVersion: Int

    public static func tests(_ kind: GameResourceKind) -> [ListScanRequest] {
        pages([1], URL(string: "http://www.vpuniverse.com")!, kind)
    }

    public static func test(_ kind: GameResourceKind) -> ListScanRequest {
        .init(URL(string: "http://www.vpuniverse.com")!, kind)
    }

    public init(_ url: URL, _ kind: GameResourceKind, page: Int = 1) {
        self.site = Site(url)
        self.base = url
        self.url = site.scanner?.update(kind: kind, url: url, page: page) ?? url
        self.page = page
        self.kind = kind
        self.scannerVersion = site.scanner?.version ?? 0
    }

    internal init(site: Site, base: URL, url: URL, page: Int, kind: GameResourceKind) {
        self.site = site
        self.base = base
        self.url = url
        self.page = page
        self.kind = kind
        self.scannerVersion = site.scanner?.version ?? 0
    }

    public static func pages(_ pages: some Collection<Int>, _ url: URL, _ kind: GameResourceKind)
        -> [ListScanRequest]
    {
        let site = Site(url)
        guard let scanner = site.scanner else { return [] }

        return pages.compactMap {
            guard let pageURL = scanner.update(kind: kind, url: url, page: $0) else {
                return nil as ListScanRequest?
            }

            return .init(site: site, base: url, url: pageURL, page: $0, kind: kind)
        }
    }

    public static func pages(_ pages: some Collection<Int>, site: Site, _ kind: GameResourceKind)
        -> [ListScanRequest]
    {
        guard let scanner = site.scanner else { return [] }
        let urls = scanner.sources(kind: kind)

        return urls.flatMap {
            Self.pages(pages, $0, kind)
        }
    }

    public func scan(content: String) async throws -> ListResult {
        guard let scanner = site.scanner else { throw ScanError.scannerNotAvailable(url) }
        return try await scanner.scanList(request: self, content: content)
    }

}

@Codable
public struct DetailResult: Hashable, Sendable, CustomStringConvertible {

    public init(
        _ detailKind: DetailKind,
        url: URL,
        kind: GameResourceKind, name: String? = nil, author: String? = nil,
        version: String? = nil, date: DateKind = .undated, ipdb: URL? = nil, text: String? = nil,
        images: [URL]? = nil, tableFeatures: Set<TableFeature> = Set<TableFeature>(),
        b2sFeatures: Set<B2SFeature> = Set<B2SFeature>()
    ) {
        self.detailKind = detailKind
        let site = Site(url)
        self.url = site.canonicalize(url)
        self.normalizedURL = site.normalize(url)
        self.site = site
        self.kind = kind
        self.name = name ?? "unknown"
        self.author = canonicalizeAuthor(author)
        self.version = version
        self.date = date
        self.text = text
        self.images = images ?? []
    }

    public var detailRequest: DetailScanRequest {
        .init(normalizedURL, kind)
    }

    public enum DetailKind: String, Codable, Sendable, Equatable {
        case list
        case detail
    }
    public let detailKind: DetailKind

    // canonical URL, e.g. has all extra data stripped
    public var url: URL

    // cleaned URL that we want to store in the database
    public var normalizedURL: URL
    public var site: Site = .other
    public var kind: GameResourceKind = .game
    public var name = "unknown"
    public var author = "unknown"
    public var version: String?
    public var text: String?
    public var images = [URL]()

    public enum DateKind: Codable, Sendable, Equatable {
        case unknown
        case undated
        case date(Date)

        public static func new(_ date: Date?) -> DateKind {
            if let date {
                .date(date)
            } else {
                .unknown
            }
        }

        public var resolved: Date {
            switch self {
            case .unknown, .undated: Date()
            case .date(let date): date
            }
        }

        public func isValid(_ other: DateKind) -> Bool {
            switch (self, other) {
            case (.unknown, _): true
            case (.undated, _): true
            case (.date(let lhs), .date(let rhs)): lhs >= rhs
            default: false
            }
        }
    }

    public var date: DateKind
    public var resolvedDate: Date { date.resolved }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(url)
        hasher.combine(name)
        hasher.combine(author)
        hasher.combine(version)
    }

    public static func == (lhs: DetailResult, rhs: DetailResult) -> Bool {
        lhs.url == rhs.url && lhs.name == rhs.name && lhs.author == rhs.author
            && lhs.version == rhs.version
    }

    public var description: String {
        [name, author, version].compactMap { $0 }.joined(separator: ", ")
    }
}

public struct ListResult: Sendable {

    public var pages: Int?

    public var list: [DetailResult]
}

extension Site {
    /// The scanner for this site, if supported.
    public var scanner: (any ScanSources & DetailScanner & ListScanner)? {
        switch self {
        case .vpu: VPUniverseScanner()
        case .vpf: VPForumsScanner()
        case .pinballPrimer: PinballPrimerScanner()
        case .youtube: YouTubeScanner()
        case .pinballnirvana: PinballNirvanaScanner()
        case .other: nil
        }
    }

    /// Scanner for a single detail page -- falls back to generic page metadata.
    public var detailScanner: any DetailScanner {
        scanner ?? WebPageScanner()
    }
}

public func trimText(_ text: String?) -> String? {
    guard var text else { return nil }

    while true {
        let new =
            text
            .replacingOccurrences(of: "\n\n", with: "\n")
            .replacingOccurrences(of: "\t\n", with: "\n")
            .replacingOccurrences(of: " \n", with: "\n")
            .replacingOccurrences(of: "  ", with: " ")
        if text == new {
            return text
        } else {
            text = new
        }
    }
}
