import Foundation
import SwiftSoup

public struct PinballPrimerScanner {
    public init() {
    }
}

extension PinballPrimerScanner: ScanSources {
    public func sources(kind: GameResourceKind) -> [URL] {
        let urls: [String] =
            switch kind {
            case .tutorial: ["https://pinballprimer.github.io/gamelist.html"]
            default: []
            }
        return urls.compactMap { URL(string: $0) }
    }

    public func update(kind: GameResourceKind, url: URL, page: Int) -> URL? {
        if page > 1 {
            return nil
        }
        return url
    }
}

extension PinballPrimerScanner: ListScanner {
    public func scanList(url: URL, content: String, kind: GameResourceKind) throws -> ListResult {
        let html = try SwiftSoup.parse(content)

        var items = [DetailResult]()

        for link in try html.select("a") {
            let url = try link.attr("href")
            if url == "index.html" || url.hasPrefix("#") { continue }
            guard let url = URL(string: "https://pinballprimer.github.io/" + url) else { continue }

            // 2001 (Gottlieb, EM, 1971)
            let title = try link.text()
                .replacingOccurrences(of: ", EM, ", with: " ")
                .replacingOccurrences(of: ", SS, ", with: " ")
                .replacingOccurrences(of: ", AN, ", with: " ")
                .replacingOccurrences(of: ", DMD, ", with: " ")
                .replacingOccurrences(of: ", LCD, ", with: " ")

            items.append(.init(url: url, kind: .tutorial, name: title, author: "Pinball Primer"))
        }

        return .init(pages: 1, list: items)
    }
}

extension PinballPrimerScanner: DetailScanner {

    public func scanDetail(url: URL, content: String, kind: GameResourceKind) throws
        -> DetailResult?
    {
        try WebPageScanner().scanDetail(url: url, content: content, kind: kind)
    }

}
