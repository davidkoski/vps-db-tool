import Foundation

enum ScanVariant: String, Codable {
    case detail
    case list
}

protocol ScanSources {
    func sources(kind: GameResourceKind) -> [URL]
    func update(kind: GameResourceKind, url: URL, page: Int) -> URL
}

protocol DetailScanner {
    func scanDetail(url: URL, content: String, kind: GameResourceKind) throws -> DetailResult?
}

protocol ListScanner {
    func scanList(url: URL, content: String, kind: GameResourceKind) throws -> ListResult
}

struct DetailResult: Codable, Hashable, Sendable, CustomStringConvertible {
    var url: URL
    var name: String?
    var author: String?
    var version: String?
    var ipdb: URL?
    var features = Set<TableFeature>()

    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
        hasher.combine(name)
        hasher.combine(author)
        hasher.combine(version)
    }

    static func == (lhs: DetailResult, rhs: DetailResult) -> Bool {
        lhs.url == rhs.url && lhs.name == rhs.name && lhs.author == rhs.author
            && lhs.version == rhs.version
    }

    var description: String {
        [name, author, version].compactMap { $0 }.joined(separator: ", ")
    }
}

struct ListResult: Sendable {

    var pages: Int?

    var list: [DetailResult]
}
