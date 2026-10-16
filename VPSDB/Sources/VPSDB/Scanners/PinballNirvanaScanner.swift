import Foundation
import ReerCodable
import SwiftSoup

public struct PinballNirvanaScanner {
    public init() {
    }
    
    public let version = 1
}

extension PinballNirvanaScanner: ScanSources {
    public func sources(kind: GameResourceKind) -> [URL] {
        let urls: [String] =
            switch kind {
            case .game: []
            case .table:
                [
                    // VPX Original Tables
                    "https://pinballnirvana.com/forums/resources/categories/vp-original-tables.35/?prefix_id[0]=24",
                    // VPX Recreations
                    "https://pinballnirvana.com/forums/resources/categories/vp-recreations.36/?prefix_id[0]=24",
                    // VPX Pinmame
                    "https://pinballnirvana.com/forums/resources/categories/visual-pinmame.2/?prefix_id[0]=24",
                    // Future Pinball
                    "https://pinballnirvana.com/forums/resources/categories/future-pinball.3/",

                ]
            case .b2s: []
            case .tutorial: []
            case .rom: []
            case .pupPack: []
            case .altColor: []
            case .altSound: []
            case .sound: []
            case .pov: []
            case .wheelArt: []
            case .topper: []
            case .mediaPack: []
            case .rule: []
            }
        return urls.compactMap { URL(string: $0) }
    }

    public func update(kind: GameResourceKind, url: URL, page: Int) -> URL? {
        if page > 1 {
            return url.appending(queryItems: [.init(name: "page", value: page.description)])
        } else {
            return url
        }
    }
}

extension PinballNirvanaScanner: DetailScanner {

    public func scanDetail(
        request: DetailScanRequest, content: String
    ) throws -> DetailResult? {
        let url = request.url
        let kind = request.kind

        let html = try SwiftSoup.parse(content)

        /*
            <h1 class="p-title-value">
            <span class="label label--pnvpten" dir="auto">VPX</span><span class="label-append">&nbsp;</span><span class="label label--silver" dir="auto">SS</span><span class="label-append">&nbsp;</span><span class="label label--royalBlue" dir="auto">Original Table</span><span class="label-append">&nbsp;</span>Uncomposed Arrangement (Lunar Howl 9)
            <span class="u-muted">1.0</span>
            </h1>

            <a href="/forums/members/anthias.9/" class="username  u-concealed" dir="auto" data-user-id="9" data-xf-init="member-tooltip" id="js-XFUniqueId2" data-xf-pointer-type="mouse">Anthias</a>
            <div class="bbWrapper">...text
         <ul class="attachmentList resourceBody-attachments">
         <li class="file file--linked">
                 <a class="u-anchorTarget" id="attachment-51798"></a>
         <a class="file-preview js-lbImage" data-lb-sidebar-href="" data-lb-caption-extra-html="" href="/forums/attachments/untitledlunar-howl-9-uncomposed-arrangement-webp.51798/" target="_blank" data-fancybox="lb-undefined" style="cursor: pointer;" data-caption="&lt;h4&gt;UntitledLunar Howl 9 Uncomposed Arrangement.webp&lt;/h4&gt;&lt;p&gt;&lt;a href=&quot;&quot; class=&quot;js-lightboxCloser&quot;&gt;&lt;/a&gt;&lt;/p&gt;">
                         <img src="/forums/data/attachments/48/48040-ccc506b7b9feba3e13ed4a7550fc6eec.jpg?hash=c-OSf1hVv_" alt="UntitledLunar Howl 9 Uncomposed Arrangement.webp" width="300" height="534" loading="lazy">
                     </a>

         https://pinballnirvana.com/forums/attachments/untitledlunar-howl-9-uncomposed-arrangement-webp.51798/

         <dl class="pairs pairs--justified">
                                     <dt>Last update</dt>
                                     <dd><time class="u-dt" dir="auto" datetime="2025-11-22T03:38:57-0500" data-timestamp="1763800737" data-date="Nov 22, 2025" data-time="3:38 AM" data-short="Nov '25" title="Nov 22, 2025 at 3:38 AM">Nov 22, 2025</time></dd>
                                 </dl>
        */
        
        let name = try html.select("h1.p-title-value").first()?.ownText().trimmingCharacters(
            in: .whitespacesAndNewlines)
        let version = try html.select("span.u-muted").text(trimAndNormaliseWhitespace: true)
        
        let labels = try html.select("h1.p-title-value .label").map { try $0.text() }
        let text = try labels.joined(separator: ", ") + ", " + html.select("article.resourceBody-main").text()

        let urls = try html.select("a.file-preview")
            .map { try $0.attr("href") }
            .compactMap { URL(string: "https://pinballnirvana.com" + $0) }

        var date: Date?
        for dl in try html.select("dl.pairs") {
            if let dt = try dl.select("dt").first(), try dt.text().contains("Last update") {
                let dateTime = try dl.select("time").attr("datetime")
                date = ISO8601DateFormatter().date(from: dateTime)
                break
            }
        }

        var author: String?
        for dl in try html.select("dl.pairs") {
            if let dt = try dl.select("dt").first(), try dt.text().contains("Author") {
                author = try dl.select(".username").text(trimAndNormaliseWhitespace: true)
                break
            }
        }

        if let name {
            return .init(
                url: url, kind: kind, name: name, author: author,
                version: version, date: date, text: text,
                images: urls)
        }

        return nil
    }
}

extension PinballNirvanaScanner: ListScanner {
    public func scanList(request: ListScanRequest, content: String) throws -> ListResult {
        let url = request.url
        let kind = request.kind

        let html = try SwiftSoup.parse(content)

        var pages: Int?
        var items = [DetailResult]()

        /*
         <ul class="pageNav-main"><li class="pageNav-page"><a ..>4</a>
         */

        let pageNav = try html.select("ul.pageNav-main")
        if !pageNav.isEmpty() {
            let lastPage = try pageNav.select("li.pageNav-page").last()
            if let text = try lastPage?.text(trimAndNormaliseWhitespace: true) {
                pages = Int(text)
            }
        }

        /*
         <div class="structItem">
         <a href="/forums/resources/who-dunnit-1947-midway-1995-bally-2021-mod.8127/" class="" data-tp-primary="on">WHO Dunnit 1947 (Midway, 1995) (Bally, 2021!) MOD</a>
         <span class="u-muted">v1.1</span>
         <a href="/forums/members/bord.24879/" class="username " dir="auto" data-user-id="24879" data-xf-init="member-tooltip" id="js-XFUniqueId40">bord</a>
         <time class="u-dt" dir="auto" datetime="2023-04-16T12:31:47-0400" data-timestamp="1681662707" data-date="Apr 16, 2023" data-time="12:31 PM" data-short="Apr '23" title="Apr 16, 2023 at 12:31 PM">Apr 16, 2023</time>
         */

        let table = try html.select("div.structItem")

        for row in table {
            let link = try row.select("a[data-tp-primary='on']")
            guard !link.isEmpty() else { continue }

            let url = try URL(string: "https://pinballnirvana.com" + link.attr("href"))
            let name = try link.text(trimAndNormaliseWhitespace: true)
            let version = try row.select("span.u-muted").text(trimAndNormaliseWhitespace: true)
            let author = try row.select("a.username").text(trimAndNormaliseWhitespace: true)

            var date: Date?
            for dl in try row.select("dl.pairs") {
                if let dt = try dl.select("dt").first(), try dt.text().contains("Updated") {
                    let dateTime = try dl.select("time").attr("datetime")
                    date = ISO8601DateFormatter().date(from: dateTime)
                    break
                }
            }

            if !name.isEmpty, let url {
                items.append(
                    .init(
                        url: url, kind: kind, name: name, author: author, version: version,
                        date: date))
            }

        }

        return .init(pages: pages, list: items)
    }
}
