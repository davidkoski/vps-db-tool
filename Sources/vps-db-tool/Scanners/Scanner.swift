import Foundation

struct SingleItem: Sendable {
    var name: String?
    var author: String?
    var version: String?
    var ipdb: URL?
    var features: Set<TableFeature>
    var b2s: URL?
    var mediaPack: URL?
    var navigations: [String]
}

struct ItemList: Sendable {

    struct Item: Sendable {
        var url: URL
        var name: String
    }

    var list: [Item]
}
