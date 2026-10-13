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
    func scanDetail(url: URL, content: String, kind: GameResourceKind) throws -> DetailResult?
}

public protocol ListScanner: Sendable {
    func scanList(url: URL, content: String, kind: GameResourceKind) throws -> ListResult
}

private let authorMap = [
    "pinballprimer.github.io": "Pinball Primer",
    "animusan2": "Animusan",
    "flyingdutchman": "Flying Dutchman",
    "xfl": "PinRich",
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
        url: URL, maxAge: Duration = .seconds(3600),
        kind: GameResourceKind, name: String? = nil, author: String? = nil,
        version: String? = nil, date: Date? = nil, ipdb: URL? = nil, text: String? = nil,
        images: [URL]? = nil, tableFeatures: Set<TableFeature> = Set<TableFeature>(),
        b2sFeatures: Set<B2SFeature> = Set<B2SFeature>()
    ) {
        if version?.isEmpty ?? false {
            print("here")
        }
        let site = Site(url)
        self.url = site.canonicalize(url)
        self.normalizedURL = site.normalize(url)
        self.maxAge = maxAge
        self.site = site
        self.kind = kind
        self.name = name ?? "unknown"
        self.author = canonicalizeAuthor(author)
        self.version = version
        self.date = date ?? Date()
        self.text = text
        self.images = images ?? []
    }

    // canonical URL, e.g. has all extra data stripped
    public var url: URL

    // cleaned URL that we want to store in the database
    public var normalizedURL: URL
    public var maxAge: Duration = .seconds(3600)
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
}

/// Fetch and scan the detail page for a (typically list-derived) ``DetailResult``.
///
/// The result has the full information -- text, images, version, etc.
public func fetchDetail(client: HTTPClient, detail: DetailResult) async throws -> DetailResult {
    try await fetchDetail(
        client: client, url: detail.normalizedURL, maxAge: detail.maxAge, kind: detail.kind)
}

/// Fetch and scan the detail page at `url` -- any site, see ``Site/detailScanner``.
public func fetchDetail(
    client: HTTPClient, url: URL, maxAge: Duration, kind: GameResourceKind
) async throws -> DetailResult {
    let site = Site(url)

    let content = try await client.getString(url, maxAge: maxAge)
    guard var result = try site.detailScanner.scanDetail(url: url, content: content, kind: kind)
    else {
        throw ScanError.unableToScanDetail(url)
    }
    result.maxAge = maxAge
    return result
}

public func gather(
    client: HTTPClient,
    maxAge: Duration,
    site: Site,
    pages: [Int] = [],
    kind: GameResourceKind,
    suppress: [URL: SuppressionReason],
    follow: @escaping @Sendable (DetailResult) -> Bool
) -> AsyncStream<DetailResult> {

    guard let scanner = site.scanner else {
        fatalError("unsupported site: \(site)")
    }

    log.info("SCAN \(site) \(kind)")

    return AsyncStream { continuation in
        var urls = [URL]()
        for listURL in scanner.sources(kind: kind) {
            if pages.isEmpty {
                urls.append(listURL)
            } else {
                urls.append(
                    contentsOf: pages.compactMap {
                        scanner.update(kind: kind, url: listURL, page: $0)
                    })
            }
        }

        let producer = Task { [urls] in
            for listURL in urls {
                log.info("SCAN ITEM \(site) \(kind) \(listURL)")

                try Task.checkCancellation()

                let content: String
                var scanResult: ListResult

                do {
                    content = try await client.getString(listURL, maxAge: maxAge)
                    scanResult = try scanner.scanList(url: listURL, content: content, kind: kind)
                    scanResult.list = scanResult.list
                        .filter {
                            if let reason = suppress[$0.url] {
                                return !reason.shouldSuppress()
                            }
                            return true
                        }
                        .map {
                            var new = $0
                            new.maxAge = maxAge
                            return new
                        }
                } catch {
                    log.error(
                        "Failed to gather from \(site) \(kind) \(listURL): \(type(of: error)) \(String(reflecting: error))"
                    )
                    continue
                }

                log.info("SCAN \(site) \(kind) - PROCESS LIST \(scanResult.list.count)")

                for item in scanResult.list {
                    log.info("PROCESS \(site) \(kind): \(item.name) \(item.url)")

                    if follow(item) {
                        do {
                            let content = try await client.getString(item.url, maxAge: maxAge)
                            var detail = try scanner.scanDetail(
                                url: item.url, content: content, kind: kind)
                            detail?.maxAge = maxAge
                            if let detail {
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

            log.info("SCAN END \(site) \(kind) result=\(urls.count)")
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
