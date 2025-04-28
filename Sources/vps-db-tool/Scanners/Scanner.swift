import Foundation

enum ScanVariant: String, Codable {
    case detail
    case list
}

protocol ScanSources {
    func source(kind: GameResourceKind, page: Int) -> String?
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
