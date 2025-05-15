import Foundation
import ReerCodable
import SwiftSoup

struct VPUniverseScanner {
}

extension VPUniverseScanner: ScanSources {
    func sources(kind: GameResourceKind) -> [URL] {
        let urls: [String] =
            switch kind {
            case .game: ["https://vpuniverse.com/files/category/104-visual-pinball/"]
            case .table:
                [
                    "https://vpuniverse.com/files/category/82-vpx-pinball-tables/"
                    //                    "https://vpuniverse.com/files/category/82-vpx-pinball-tables/",
                    //                    "https://vpuniverse.com/files/category/131-pup-pack-original-pup-original-game-creations/",
                    //                    "https://vpuniverse.com/files/category/123-modified-mod-games/",
                    //                    "https://vpuniverse.com/files/category/114-vpx-full-single-screen-tables-fss/",
                    //                    "https://vpuniverse.com/files/category/146-vpx-flipperless/",
                ]
            case .b2s:
                [
                    "https://vpuniverse.com/files/category/33-b2s-directb2s-backglass-downloads/",
                    "https://vpuniverse.com/files/category/175-full-dmd-backglasses/",
                ]
            case .tutorial: []
            case .rom: ["https://vpuniverse.com/files/category/15-pinmame-roms/"]
            case .pupPack:
                [
                    "https://vpuniverse.com/files/category/120-pup-packs/",
                    "https://vpuniverse.com/files/category/121-2-screen-4x3-pup-packs/",
                ]
            case .altColor:
                ["https://vpuniverse.com/files/category/101-pin2dmd-colorizations-virtual-pinball/"]
            case .altSound: ["https://vpuniverse.com/files/category/113-altsound/"]
            case .sound: []
            case .pov:
                ["https://vpuniverse.com/files/category/68-vpx-pov-point-of-view-physics-sets/"]
            case .wheelArt:
                [
                    "https://vpuniverse.com/files/category/70-wheel-images/",
                    "https://vpuniverse.com/files/category/127-tarcisio-style-wheels/",
                    "https://vpuniverse.com/files/category/149-animated-wheel-images-apng/",
                ]
            case .topper: ["https://vpuniverse.com/files/category/160-topper-videos/"]
            case .mediaPack: ["https://vpuniverse.com/files/category/9-hyperpin-media-packs/"]
            case .rule: ["https://vpuniverse.com/files/category/91-instruction-cards/"]
            }
        return urls.compactMap { URL(string: $0) }
    }

    func update(kind: GameResourceKind, url: URL, page: Int) -> URL {
        if page > 1 {
            return url.appending(components: "page", page.description)
        } else {
            return url
        }
    }
}

extension VPUniverseScanner: DetailScanner {

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
         VR Room
         <div id='ipsTabs_tabs_file_file_tab_downloads_field_21_panel' class="ipsTabs_panel MVN_lsDownloads_viewCustom1_sectionPadding" aria-labelledby="file_tab_field_21" aria-hidden="false">
             <div class='ipsType_richText ipsContained ipsType_break' data-controller='core.front.core.lightboxedImages'>
                 Yes
             </div>
         </div>

         */
        var vr = false
        for item in try html.select(
            "div#ipsTabs_tabs_file_file_tab_downloads_field_21_panel div.ipsType_richText")
        {
            if try item.text() == "Yes" {
                vr = true
            }
        }

        /*
         IPDB

         <div id='ipsTabs_tabs_file_file_tab_downloads_field_2_panel' class="ipsTabs_panel MVN_lsDownloads_viewCustom1_sectionPadding" aria-labelledby="file_tab_field_2" aria-hidden="false">
             <div class='ipsType_richText ipsContained ipsType_break' data-controller='core.front.core.lightboxedImages'>
                 https://www.ipdb.org/machine.cgi?id=4858
             </div>
         </div>

         */
        var ipdbURL: URL?
        for item in try html.select(
            "div#ipsTabs_tabs_file_file_tab_downloads_field_2_panel div.ipsType_richText")
        {
            if let url = URL(string: try item.text()) {
                ipdbURL = url
            }
        }

        /*
         <script type='application/ld+json'>
         {
             "@context": "http://schema.org",
             "@type": "WebApplication",
         */
        for script in try html.select("script") {
            guard try script.attr("type") == "application/ld+json" else { continue }
            guard
                let meta = try? JSONDecoder().decode(
                    Meta.self, from: script.html().data(using: .utf8)!)
            else { continue }

            var features = scanFeatures(meta.description)
            if vr {
                features.insert(.vr)
            }

            return .init(
                url: Site(url).canonicalize(url),
                name: meta.name,
                author: meta.author.name,
                version: meta.softwareVersion,
                ipdb: ipdbURL,
                features: features
            )
        }

        return nil
    }
}

extension VPUniverseScanner: ListScanner {
    func scanList(url: URL, content: String, kind: GameResourceKind) throws -> ListResult {
        let html = try SwiftSoup.parse(content)

        var pages: Int?
        var items = [DetailResult]()

        /*
         <li class=ipsPagination_pageJump>
         <li class='ipsFieldRow'>
             <input type='number' min='1' max='85' placeholder='Page number' class='ipsField_fullWidth' name='page'>
         </li>
         */
        let pageInput = try html.select("li.ipsPagination_pageJump input")
        if !pageInput.isEmpty() {
            pages = try Int(pageInput[0].attr("max"))
        }

        /*
         <div class=ipsDataItem_main>
         <h4>
         <span class="ipsType_break ipsContained"><a href="https://vpuniverse.com/files/file/25136-iron-eagle-original-2025/" title="View the file Iron Eagle (Original 2025) " >Iron Eagle (Original 2025)</a></span>
         */
        for item in try html.select("div.ipsDataItem_main") {
            var url = ""
            var title = ""
            var author = ""

            let a = try item.select("h4 a")
            url = try a.attr("href")
            title = try a.text()

            if url.contains("/tags/") {
                // sometimes they have nav by tag
                continue
            }

            let span = try item.select("p.ipsType_reset a")
            author = try span.text()

            if !url.isEmpty && !title.isEmpty, let url = URL(string: url) {
                items.append(.init(url: url, name: title, author: author))
            }
        }

        return .init(pages: pages, list: items)
    }
}
