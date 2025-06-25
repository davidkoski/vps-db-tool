import Foundation
import ReerCodable
import SwiftSoup

public struct VPForumsScanner {

    /// 20 Apr 2025
    private let dateFormat: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "dd MM yyyy"
        return df
    }()

    public init() {
    }
}

extension VPForumsScanner: ScanSources {
    public func sources(kind: GameResourceKind) -> [URL] {
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

    public func update(kind: GameResourceKind, url: URL, page: Int) -> URL {
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

    func splitName(_ text: String) -> (name: String, version: String) {
        var name: String

        // Count-Down (Gottlieb 1978) JP v5.5 DT-FS-VR-MR Ext2k Conversion 2.0
        let pieces = text.split(separator: ") ")
        let pieces2 = text.split(separator: " ")

        if pieces.count == 2 {
            name = pieces[0] + ")"
        } else {
            name = pieces2.dropLast().joined(separator: " ")
        }

        let version2 = String(pieces2.last ?? "")
        return (name, version2)
    }

    public func scanDetail(url: URL, content: String, kind: GameResourceKind) throws
        -> DetailResult?
    {
        let html = try SwiftSoup.parse(content)

        /*
         <h1 class='ipsType_pagetitle'>
         <a href='...' class='download_button rounded right'>Download</a>
         Future Spa (Bally 1979) 5.5.1
         */

        if let titleVersion = try html.select("h1.ipsType_pagetitle").first() {
            let text = try titleVersion.text()
                .replacingOccurrences(of: "Download ", with: "")

            let (name, version) = splitName(text)

            return .init(
                url: Site(url).canonicalize(url),
                name: name,
                author: nil,
                version: version
            )
        }

        return nil
    }
}

extension VPForumsScanner: ListScanner {
    public func scanList(url: URL, content: String, kind: GameResourceKind) throws -> ListResult {
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

        // typical category page
        let category = try html.select("div.idm_category_row")
        if !category.isEmpty {
            /*

             <h3 class="ipsType_subtitle">
             <a href="https://www.vpforums.org/index.php?app=downloads&amp;showfile=18336" title="View file named Close Encounters">Close Encounters <span class="ipsType_small">1.4.3</span></a>
             */
            for item in category {
                let a = try item.select("h3.ipsType_subtitle a")
                let url = try a.attr("href")
                let title = try a.attr("title")
                    .replacingOccurrences(of: "View file named ", with: "")

                let version = try a.select("span.ipsType_small").text()

                // By xxx
                let div = try item.select("div.lighter").html()
                let author = String(div.split(separator: "<")[0].dropFirst(3)).trimmingCharacters(
                    in: .whitespacesAndNewlines)

                let dateText = try item.select("span.date")
                    .text()
                    .replacingOccurrences(of: "Updated", with: "")
                    .replacingOccurrences(of: "Added", with: "")
                    .trimmingCharacters(in: .whitespaces)
                let date = dateFormat.date(from: dateText)

                if !url.isEmpty && !title.isEmpty, let url = URL(string: url) {
                    items.append(
                        .init(
                            url: Site(url).canonicalize(url),
                            name: title, author: author,
                            version: version, date: date
                        ))
                }
            }
        }

        // Content page, e.g. JP's content:
        // https://www.vpforums.org/index.php?app=core&module=search&do=user_activity&mid=277&search_app=downloads&userMode=all&sid=5eaf50d4d8666e5b03a99f2924d2b22f&search_app_filters%5Bdownloads%5D%5BsearchInKey%5D=files&search_app_filters%5Bdownloads%5D%5Bfiles%5D%5BsortKey%5D=date&st=0&num=10&st=200
        let contentPage = try html.select("table.ipb_table tr")
        if !contentPage.isEmpty {
            for item in contentPage {
                let a = try item.select("h3.ipsType_subtitle a")
                let url = try a.attr("href")
                let title = try a.attr("title")
                    .replacingOccurrences(of: "View file named ", with: "")

                let version = try a.select("span.ipsType_small").text()

                let list = try item.select("ul.last_post li")
                let author = list.count == 2 ? try list[0].text() : nil

                let dateText =
                    list.count == 2
                    ? try list[1]
                        .text()
                        .split(separator: "-")[0]
                        .trimmingCharacters(in: .whitespaces)
                    : ""
                let date = dateFormat.date(from: dateText)

                if !url.isEmpty && !title.isEmpty, let url = URL(string: url) {
                    items.append(
                        .init(
                            url: Site(url).canonicalize(url),
                            name: title, author: author,
                            version: version, date: date
                        ))
                }
            }
        }

        return .init(pages: pages, list: items)
    }
}
