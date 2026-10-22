import Foundation
import Logging

private let log = Logger(label: "ScanCache")

struct CacheListResult: Codable, Sendable, Equatable {
    public var pages: Int?

    public let kind: GameResourceKind
    public let version: Int

    /// dates and canonical urls
    public struct Item: Codable, Equatable {
        let date: DetailResult.DateKind
        let url: URL

        init(_ detail: DetailResult) {
            self.date = detail.date
            self.url = detail.url
        }

        func detailRequest(_ kind: GameResourceKind) -> DetailScanRequest {
            .init(url, kind, updated: date)
        }
    }
    public var items: [Item]

    public var created = Date()

    init(request: ListScanRequest, list: ListResult) {
        self.pages = list.pages
        self.kind = request.kind
        self.version = request.scannerVersion
        self.items = list.list.map { Item.init($0) }
    }

    public func isExpired(maxAge: Duration) -> Bool {
        return Int64(-created.timeIntervalSinceNow) > maxAge.components.seconds
    }

    public func reconstitute(scanCache: ScanCache?) async -> ListResult? {
        guard let scanCache else { return nil }

        var details = [DetailResult]()
        for item in items {
            let request = item.detailRequest(kind)
            guard let detail = await scanCache.get(request: request),
                detail.date.isValid(item.date)
            else {
                log.info("Failed to reconstitute -- missing \(request.canonicalURL)")
                return nil
            }
            details.append(detail)
        }

        return .init(pages: pages, list: details)
    }
}

public actor ScanCache {

    // Site, Scanner.version, baseUrl, page, ListResult
    private var listCache = [Site: [Int: [URL: [Int: CacheListResult]]]]()

    // Site, Scanner.version, GameResourceKind, canonicalUrl, DetailResult
    private var detailCache = [Site: [Int: [GameResourceKind: [URL: DetailResult]]]]()

    private var url: URL?
    private var dirty = false

    private var marking = false
    private var marks = [Site: [Int: [GameResourceKind: Set<URL>]]]()

    private struct Contents: Codable {
        var list = [Site: [Int: [URL: [Int: CacheListResult]]]]()
        var details = [Site: [Int: [GameResourceKind: [URL: DetailResult]]]]()
    }

    public init() {
    }

    public func load(url: URL) throws {
        self.url = url
        if let data = try? Data(contentsOf: url) {
            log.info("Loaded \(data.count) bytes")
            let contents = try JSONDecoder().decode(Contents.self, from: data)
            self.listCache = contents.list
            self.detailCache = contents.details
        }
    }

    public var listCount: Int {
        var listCount = 0
        for (_, versionDict) in listCache {
            for (_, urlDict) in versionDict {
                for (_, pageDict) in urlDict {
                    listCount += pageDict.count
                }
            }
        }
        return listCount
    }

    public var detailCount: Int {
        var detailCount = 0
        for (_, versionDict) in detailCache {
            for (_, kindDict) in versionDict {
                for (_, urlDict) in kindDict {
                    detailCount += urlDict.count
                }
            }
        }
        return detailCount
    }

    public func save() throws {
        guard let url else { return }
        guard dirty else { return }

        let contents = Contents(list: listCache, details: detailCache)
        let data = try JSONEncoder().encode(contents)
        try data.write(to: url, options: .atomic)
        dirty = false
    }

    public func mark() {
        marking = true
        marks = .init()
    }

    public func sweep() {
        guard marking else { return }
        marking = false

        for (site, versionDict) in detailCache {
            guard let marksVersionDict = marks[site] else {
                detailCache[site] = nil
                dirty = true
                continue
            }
            for (version, kindDict) in versionDict {
                guard let marksKindDict = marksVersionDict[version] else {
                    detailCache[site]?[version] = nil
                    dirty = true
                    continue
                }
                for (kind, urlDict) in kindDict {
                    guard let marksURLSet = marksKindDict[kind] else {
                        detailCache[site]?[version]?[kind] = nil
                        dirty = true
                        continue
                    }
                    for (url, _) in urlDict {
                        if !marksURLSet.contains(url) {
                            detailCache[site]?[version]?[kind]?[url] = nil
                            dirty = true
                        }
                    }
                }
            }
        }

        marks = .init()
    }

    public func cache(request: DetailScanRequest, item: DetailResult) {
        if let existing = detailCache[request.site]?[request.scannerVersion]?[request.kind]?[
            request.canonicalURL]
        {
            if existing == item {
                return
            }
            if item.detailKind == .list && existing.detailKind == .detail {
                // don't overwrite a detail with a list version
                return
            }
        }

        log.info("cache detail(\(item.detailKind.rawValue)) \(request.canonicalURL)")

        detailCache[request.site, default: [:]][request.scannerVersion, default: [:]][
            request.kind, default: [:]][request.canonicalURL] = item

        // TODO dkoski remove if the scannerVersion changes

        if marking {
            marks[request.site, default: [:]][request.scannerVersion, default: [:]][
                request.kind, default: []
            ].insert(request.canonicalURL)
        }

        dirty = true
    }

    public func invalidate(request: DetailScanRequest) {
        log.info("invalidate detail \(request.canonicalURL)")

        detailCache[request.site, default: [:]][request.scannerVersion, default: [:]][
            request.kind, default: [:]][request.canonicalURL] = nil
        dirty = true
    }

    public func get(request: DetailScanRequest) -> DetailResult? {
        // TODO dkoski attach a date to the request and compare
        let result = detailCache[request.site]?[request.scannerVersion]?[request.kind]?[
            request.canonicalURL]

        log.info("detail \(result == nil ? "MISS" : "HIT") \(request.canonicalURL)")

        return result
    }

    public func cache(request: ListScanRequest, item: ListResult) {
        // cache the list items
        for detail in item.list {
            cache(request: detail.detailRequest, item: detail)
        }

        let cacheItem = CacheListResult(request: request, list: item)

        listCache[request.site, default: [:]][request.scannerVersion, default: [:]][
            request.base, default: [:]][request.page] = cacheItem

        // TODO dkoski remove if the scannerVersion changes

        dirty = true
    }

    public func invalidate(request: ListScanRequest) {
        listCache[request.site, default: [:]][request.scannerVersion, default: [:]][request.base] =
            nil
        dirty = true
    }

    func get(request: ListScanRequest) -> CacheListResult? {
        listCache[request.site]?[request.scannerVersion]?[request.base]?[request.page]
    }
}
