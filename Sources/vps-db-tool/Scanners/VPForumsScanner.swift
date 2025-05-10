import Foundation
import ReerCodable
import SwiftSoup

struct VPForumsScanner {
}

extension VPForumsScanner: ScanSources {
    func sources(kind: GameResourceKind) -> [URL] {
        let urls: [String] =
            switch kind {
            case .game:
                [
                    "https://www.vpforums.org/index.php?app=downloads&showcat=50&dosort=1&sort_key=file_updated&sort_order=desc&num=&filter_key="
                ]
            case .table:
                [
                    "https://www.vpforums.org/index.php?app=downloads&showcat=50&dosort=1&sort_key=file_updated&sort_order=desc&num=&filter_key="
                ]
            case .b2s:
                [
                    "https://www.vpforums.org/index.php?app=downloads&showcat=42&dosort=1&sort_key=file_updated&sort_order=desc&num=&filter_key="
                ]
            case .tutorial: []
            case .rom:
                [
                    "https://www.vpforums.org/index.php?app=downloads&showcat=9&dosort=1&sort_key=file_updated&sort_order=desc&num=&filter_key="
                ]
            case .pupPack:
                []
            case .altColor:
                []
            case .altSound: []
            case .sound: []
            case .pov:
                []
            case .wheelArt:
                [
                    "https://www.vpforums.org/index.php?app=downloads&showcat=27&dosort=1&sort_key=file_updated&sort_order=desc&num=&filter_key="
                ]
            case .topper:
                [
                    "https://www.vpforums.org/index.php?app=downloads&showcat=55&dosort=1&sort_key=file_updated&sort_order=desc&num=&filter_key="
                ]
            case .mediaPack:
                [
                    "https://www.vpforums.org/index.php?app=downloads&showcat=35&dosort=1&sort_key=file_updated&sort_order=desc&num=&filter_key="
                ]
            case .rule: []
            }
        return urls.compactMap { URL(string: $0) }
    }

    func update(kind: GameResourceKind, url: URL, page: Int) -> URL {
        // input: https://www.vpforums.org/index.php?app=downloads&showcat=50&dosort=1&sort_key=file_updated&sort_order=desc&num=&filter_key=
        // output: https://www.vpforums.org/index.php?app=downloads&showcat=50&sort_order=desc&sort_key=file_updated&num=10&st=10
        if page > 1 {
            let urlString = url.description
                .replacingOccurrences(of: "num=&", with: "")
                .replacingOccurrences(of: "filter_key=", with: "")
                .replacingOccurrences(of: "dosort=1&", with: "")
            let new = URL(string: urlString)!
            return new.appending(queryItems: [
                .init(name: "num", value: "10"),
                .init(name: "st", value: ((page - 1) * 10).description),
            ])
        } else {
            return url
        }
    }
}

extension VPForumsScanner: DetailScanner {

    func scanFeatures(_ text: String) -> Set<TableFeature> {
        var result = Set<TableFeature>()

        if text.contains(/fozzy/.ignoresCase()) {
            result.insert(.nFozzy)
        }
        if text.contains(/fleep/.ignoresCase()) {
            result.insert(.fleep)
        }
        if text.contains(/vr ?room/.ignoresCase()) {
            result.insert(.vr)
        }
        if text.contains(/Mixed Reality/.ignoresCase()) {
            result.insert(.mixedReality)
        }

        return result
    }

    @Codable
    struct Meta {
        let name: String

        let description: String
        let softwareVersion: String

        struct Author: Codable {
            let name: String
        }

        let author: Author

        @DateCoding(.iso8601)
        let dateModified: Date?

        @DateCoding(.iso8601)
        let dateCreated: Date
    }

    func scanDetail(url: URL, content: String, kind: GameResourceKind) throws -> DetailResult? {
        let html = try SwiftSoup.parse(content)

        /*
         <h1 class='ipsType_pagetitle'>
         <a href='...' class='download_button rounded right'>Download</a>
         Future Spa (Bally 1979) 5.5.1
         */

        if let titleVersion = try html.select("h1.ipsType_pagetitle").first() {
            let text = try titleVersion.text()
                .replacingOccurrences(of: "Download ", with: "")
            let pieces = text.split(separator: ") ")
            if pieces.count == 2 {
                return .init(
                    url: Site(url).canonicalize(url),
                    name: pieces[0] + ")",
                    author: nil,
                    version: String(pieces[1])
                )
            }

            let pieces2 = text.split(separator: " ")
            let version2 = String(pieces2.last ?? "")
            let name2 = pieces2.dropLast().joined(separator: " ")

            return .init(
                url: Site(url).canonicalize(url),
                name: name2,
                author: nil,
                version: version2
            )
        }

        return nil
    }
}

extension VPForumsScanner: ListScanner {
    func scanList(url: URL, content: String, kind: GameResourceKind) throws -> ListResult {
        let html = try SwiftSoup.parse(content)

        var pages: Int?
        var items = [DetailResult]()

        /*
         <li class="last"><a href="https://www.vpforums.org/index.php?app=downloads&amp;showcat=50&amp;sort_order=desc&amp;sort_key=file_updated&amp;num=10&amp;st=2260" title="Go to last page" rel="last">»</a></li>
         <a href="https://www.vpforums.org/index.php?app=downloads&amp;showcat=50&amp;sort_order=desc&amp;sort_key=file_updated&amp;num=10&amp;st=2260" title="Go to last page" rel="last">»</a>
         */
        let pageArrow = try html.select("li.last a")
        if !pageArrow.isEmpty() {
            let href = try pageArrow.attr("href")
            if let url = URLComponents(string: href) {
                if let pageItem = url.queryItems?.first(where: { $0.name == "st" }),
                    let pageString = pageItem.value,
                    let st = Int(pageString)
                {
                    pages = st / 10 + 1
                }
            }
        }

        /*
         <h3 class="ipsType_subtitle">
         <a href="https://www.vpforums.org/index.php?app=downloads&amp;showfile=18336" title="View file named Close Encounters">Close Encounters <span class="ipsType_small">1.4.3</span></a>
         */
        for item in try html.select("h3.ipsType_subtitle a") {
            let url = try item.attr("href")
            let title = try item.text()

            if !url.isEmpty && !title.isEmpty, let url = URL(string: url) {
                items.append(.init(url: Site(url).canonicalize(url), name: title))
            }
        }

        return .init(pages: pages, list: items)
    }
}
