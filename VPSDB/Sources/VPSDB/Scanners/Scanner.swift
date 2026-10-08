import Foundation
import Logging

private let log = Logger(label: "Scanner")

public enum ScanVariant: String, Codable {
    case detail
    case list
}

public protocol ScanSources {
    func sources(kind: GameResourceKind) -> [URL]
    func update(kind: GameResourceKind, url: URL, page: Int) -> URL
}

public protocol DetailScanner {
    func scanDetail(url: URL, content: String, kind: GameResourceKind) throws -> DetailResult?
}

public protocol ListScanner {
    func scanList(url: URL, content: String, kind: GameResourceKind) throws -> ListResult
}

public struct DetailResult: Codable, Hashable, Sendable, CustomStringConvertible {
    public init(url: URL, name: String? = nil, author: String? = nil, version: String? = nil, date: Date? = nil, ipdb: URL? = nil, text: String? = nil, images: [URL]? = nil, features: Set<TableFeature> = Set<TableFeature>()) {
        self.url = url
        self.name = name
        self.author = author
        self.version = version
        self.date = date
        self.ipdb = ipdb
        self.text = text
        self.images = images
        self.features = features
    }
    

    public var url: URL
    public var name: String?
    public var author: String?
    public var version: String?
    public var date: Date?
    public var ipdb: URL?
    public var text: String?
    public var images: [URL]?
    public var features = Set<TableFeature>()

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

public func gather(
    client: HTTPClient,
    site: Site,
    pages: [Int] = [],
    kind: GameResourceKind,
    follow: (DetailResult) -> Bool
) async throws -> [DetailResult] {

    let scanner: ScanSources & DetailScanner & ListScanner =
        switch site {
        case .vpu: VPUniverseScanner()
        case .vpf: VPForumsScanner()
        case .pinballnirvana, .other: fatalError()
        }

    log.info("SCAN \(site) \(kind)")

    var result = [DetailResult]()
    
    var urls = [URL]()
    for listURL in scanner.sources(kind: kind) {
        if pages.isEmpty {
            urls.append(listURL)
        } else {
            for page in pages {
                urls.append(scanner.update(kind: kind, url: listURL, page: page))
            }
        }
    }

    for listURL in urls {
        log.info("SCAN ITEM \(site) \(kind) \(listURL)")

        let content: String
        let scanResult: ListResult

        do {
            content = try await client.getString(listURL, bypassCache: true)
            scanResult = try scanner.scanList(url: listURL, content: content, kind: kind)
        } catch {
            log.error(
                "Failed to gather from \(site) \(kind) \(listURL): \(type(of: error)) \(String(reflecting: error))"
            )
            continue
        }

        log.info("SCAN \(site) \(kind) - PROCESS LIST \(scanResult.list.count)")

        for item in scanResult.list {
            log.info("PROCESS \(site) \(kind): \(item.name ?? "unknown") \(item.url)")

            if follow(item) {
                do {
                    let content = try await client.getString(item.url)
                    let detail = try scanner.scanDetail(url: item.url, content: content, kind: kind)
                    if let detail {
                        result.append(detail)
                    }
                } catch {
                    log.error(
                        "Error fetching \(item.url): \(type(of: error)) \(String(reflecting: error))")
                    result.append(item)
                }
            } else {
                result.append(item)
            }
        }
    }

    log.info("SCAN END \(site) \(kind) result=\(result.count)")
    
    return result
}
