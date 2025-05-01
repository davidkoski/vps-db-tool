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

struct DetailResult: Sendable {
    var name: String?
    var author: String?
    var version: String?
    var ipdb: URL?
    var features: Set<TableFeature>
    var b2s: URL?
    var mediaPack: URL?
    var navigations: [String]
}

struct ListResult: Sendable {

    var pages: Int?

    struct Item: Sendable {
        var url: URL
        var name: String
        var author: String?
    }

    var list: [Item]
}
