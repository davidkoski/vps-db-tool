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

    public func update(kind: GameResourceKind, url: URL, page: Int) -> URL? {
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

    func splitName(_ text: String) -> (name: String, version: String) {
        // VPF specific cleanup:
        //   Cerberus wheel
        //   Boxster Pinball (JPSalas 2010).png
        let text =
            text
            .replacingOccurrences(of: " wheel", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: " backglass", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: ".png", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: ".webp", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "(JPSalas ", with: "(Original ", options: .caseInsensitive)

        // Count-Down (Gottlieb 1978) JP v5.5 DT-FS-VR-MR Ext2k Conversion 2.0
        let title = ReleaseTitle(text)

        // the detail scan requires a version
        return (title.title, title.version ?? "1.0")
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
            let titleText = try titleVersion.text()
                .replacingOccurrences(of: "Download ", with: "")

            let (name, version) = splitName(titleText)

            var date: Date?
            let dateText = try html.select("li strong")
            for item in dateText.array() {
                if try item.text().hasPrefix("Last Updated:"), let text = try item.parent()?.text()
                {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "MMM dd yyyy hh:mm a"
                    formatter.locale = Locale(identifier: "en_US_POSIX")

                    date = formatter.date(
                        from: text.replacingOccurrences(of: "Last Updated:", with: "")
                            .trimmingCharacters(in: .whitespacesAndNewlines))
                    break
                }
            }

            var author: String?
            let author1 = try html.select(".name")
            let author2 = try html.select(".ipsType_subtitle")
            let authorElement = author1.isEmpty() ? author2 : author1
            if !authorElement.isEmpty() {
                author = try authorElement[0].text(trimAndNormaliseWhitespace: true)
            }

            var text: String?
            let textElement = try html.select(".description_content")
            if !textElement.isEmpty() {
                text = try textElement[0].text(trimAndNormaliseWhitespace: true)
            }

            let screenShotElement = try html.select(".screenshot")
            let images = try? screenShotElement.compactMap {
                try URL(string: $0.attr("href"))
            }

            return .init(
                url: url,
                kind: kind,
                name: name,
                author: author,
                version: version,
                date: date,
                text: text,
                images: images
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

                var version: String? = try a.select("span.ipsType_small").text()
                if version?.isEmpty ?? false {
                    version = nil
                }

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
                            url: url,
                            kind: kind,
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

                var version: String? = try a.select("span.ipsType_small").text()
                if version?.isEmpty ?? false {
                    version = nil
                }

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
                            url: url,
                            kind: kind,
                            name: title, author: author,
                            version: version, date: date
                        ))
                }
            }
        }

        return .init(pages: pages, list: items)
    }
}
