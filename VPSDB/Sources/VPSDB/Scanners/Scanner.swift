import Foundation
import Logging
import ReerCodable

private let log = Logger(label: "Scanner")

public enum ScanVariant: String, Codable {
    case detail
    case list
}

public protocol ScanSources {
    func sources(kind: GameResourceKind) -> [URL]
    func update(kind: GameResourceKind, url: URL, page: Int) -> URL?
}

public protocol DetailScanner: Sendable {
    func scanDetail(request: DetailScanRequest, content: String) async throws -> DetailResult?
}

public protocol ListScanner: Sendable {
    func scanList(request: ListScanRequest, content: String) async throws -> ListResult
}

public protocol ScanRequest: Sendable {
    var site: Site { get }
    var url: URL { get }
    var kind: GameResourceKind { get }
}

public struct DetailScanRequest: ScanRequest, Hashable {
    public let site: Site
    public let url: URL
    public let kind: GameResourceKind

    public static func test(_ kind: GameResourceKind) -> Self {
        .init(URL(string: "http://www.vpuniverse.com")!, kind)
    }

    public init(_ url: URL, _ kind: GameResourceKind) {
        self.site = Site(url)
        self.url = url
        self.kind = kind
    }

    public func scan(content: String) async throws -> DetailResult? {
        try await site.scanner?.scanDetail(request: self, content: content)
    }

    public func fetch(
        client: HTTPClient, maxAge: Duration = .seconds(3600)
    ) async throws -> DetailResult {
        let content = try await client.getString(url, maxAge: maxAge)
        guard let result = try await scan(content: content) else {
            throw ScanError.unableToScanDetail(url)
        }
        return result
    }
}

public struct ListScanRequest: ScanRequest, Hashable {
    public let site: Site
    public let base: URL
    public let url: URL
    public let page: Int
    public let kind: GameResourceKind

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
    }

    internal init(site: Site, base: URL, url: URL, page: Int, kind: GameResourceKind) {
        self.site = site
        self.base = base
        self.url = url
        self.page = page
        self.kind = kind
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

private let authorMap = [
    "pinballprimer.github.io": "Pinball Primer",
    "animusan2": "Animusan",
    "flyingdutchman": "Flying Dutchman",
    "xfl": "PinRich",
    "francisco pozo robles": "Francisco",
    "francisco pozo": "Francisco",
    "francisco666": "Francisco",
]

public func canonicalizeAuthor(_ author: String?) -> String {
    guard let author else { return "unknown" }

    let trimmedAuthor =
        author
        .replacingOccurrences(of: "&nbsp;", with: " ")
        .trimmingCharacters(in: .whitespacesAndNewlines)

    if let replacement = authorMap[trimmedAuthor.lowercased()] {
        return replacement
    } else {
        return trimmedAuthor
    }
}

@Codable
public struct DetailResult: Hashable, Sendable, CustomStringConvertible {

    public init(
        url: URL,
        kind: GameResourceKind, name: String? = nil, author: String? = nil,
        version: String? = nil, date: Date? = nil, ipdb: URL? = nil, text: String? = nil,
        images: [URL]? = nil, tableFeatures: Set<TableFeature> = Set<TableFeature>(),
        b2sFeatures: Set<B2SFeature> = Set<B2SFeature>()
    ) {
        let site = Site(url)
        self.url = site.canonicalize(url)
        self.normalizedURL = site.normalize(url)
        self.site = site
        self.kind = kind
        self.name = name ?? "unknown"
        self.author = canonicalizeAuthor(author)
        self.version = version
        self.date = date ?? Date()
        self.text = text
        self.images = images ?? []
    }

    public var detailRequest: DetailScanRequest {
        .init(url, kind)
    }

    // canonical URL, e.g. has all extra data stripped
    public var url: URL

    // cleaned URL that we want to store in the database
    public var normalizedURL: URL
    public var site: Site = .other
    public var kind: GameResourceKind = .game
    public var name = "unknown"
    public var author = "unknown"
    public var version: String?
    public var date = Date()
    public var text: String?
    public var images = [URL]()

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

public enum ScanError: Error {
    case unableToScanDetail(URL)
    case scannerNotAvailable(URL)
}

public func gather(
    client: HTTPClient,
    maxAge: Duration,
    requests: [ListScanRequest],
    suppress: [URL: SuppressionReason],
    follow: @escaping @Sendable (DetailResult) -> Bool
) -> AsyncStream<DetailResult> {

    return AsyncStream { continuation in
        let producer = Task {
            var maxPage = Int.max
            for request in requests {
                log.info("SCAN ITEM \(request.site) \(request.kind) \(request.url)")

                if request.page > maxPage {
                    continue
                }

                try Task.checkCancellation()

                var scanResult: ListResult

                do {
                    let content = try await client.getString(request.url, maxAge: maxAge)
                    scanResult = try await request.scan(content: content)
                    if let pages = scanResult.pages, maxPage == .max {
                        maxPage = pages
                    }
                    scanResult.list = scanResult.list
                        .filter {
                            if let reason = suppress[$0.url] {
                                return !reason.shouldSuppress()
                            }
                            return true
                        }
                } catch {
                    log.error(
                        "Failed to gather from \(request.site) \(request.kind) \(request.url): \(type(of: error)) \(String(reflecting: error))"
                    )
                    continue
                }

                log.info(
                    "SCAN \(request.site) \(request.kind) - PROCESS LIST \(scanResult.list.count)")

                for item in scanResult.list {
                    log.info("PROCESS \(request.site) \(request.kind): \(item.name) \(item.url)")

                    if follow(item) {
                        do {
                            let detailRequest = item.detailRequest
                            let content = try await client.getString(item.url, maxAge: maxAge)
                            if let detail = try await detailRequest.scan(content: content) {
                                continuation.yield(detail)
                            }
                        } catch {
                            log.error(
                                "Error fetching \(item.url): \(type(of: error)) \(String(reflecting: error))"
                            )
                            continuation.yield(item)
                        }
                    } else {
                        continuation.yield(item)
                    }
                }
            }

            continuation.finish()
        }

        continuation.onTermination = { _ in
            producer.cancel()
        }
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
