import Foundation

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
    public init(url: URL, name: String? = nil, author: String? = nil, version: String? = nil, ipdb: URL? = nil, features: Set<TableFeature> = Set<TableFeature>()) {
        self.url = url
        self.name = name
        self.author = author
        self.version = version
        self.ipdb = ipdb
        self.features = features
    }
    
    public var url: URL
    public var name: String?
    public var author: String?
    public var version: String?
    public var ipdb: URL?
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
