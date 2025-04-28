import Foundation
import HelperCoders
import MetaCodable
import SwiftSoup

struct VPUniverseScanner {
}

extension VPUniverseScanner: ScanSources {
    func source(kind: GameResourceKind, page: Int) -> String? {
        let base: String? =
            switch kind {
            case .game: "https://vpuniverse.com/files/category/104-visual-pinball/"
            case .table:
                // in theory it should be
                // "https://vpuniverse.com/files/category/82-vpx-pinball-tables/"
                //
                // but that has 64 pages vs 85 in this parent
                "https://vpuniverse.com/files/category/104-visual-pinball/"
            case .b2s: "https://vpuniverse.com/files/category/33-b2s-directb2s-backglass-downloads/"
            case .tutorial: nil
            case .rom: "https://vpuniverse.com/files/category/15-pinmame-roms/"
            case .pupPack: "https://vpuniverse.com/files/category/120-pup-packs/"
            case .altColor:
                "https://vpuniverse.com/files/category/101-pin2dmd-colorizations-virtual-pinball/"
            case .altSound: "https://vpuniverse.com/files/category/113-altsound/"
            case .pov:
                "https://vpuniverse.com/files/category/68-vpx-pov-point-of-view-physics-sets/"
            case .wheelArt: "https://vpuniverse.com/files/category/70-wheel-images/"
            case .topper: "https://vpuniverse.com/files/category/160-topper-videos/"
            case .mediaPack: "https://vpuniverse.com/files/category/9-hyperpin-media-packs/"
            case .rule: "https://vpuniverse.com/files/category/91-instruction-cards/"
            }
        if let base, page > 1 {
            return base + "page/\(page)"
        } else {
            return base
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

        @Default(ifMissing: "") let description: String
        let softwareVersion: String

        struct Author: Codable {
            let name: String
        }

        let author: Author

        @CodedBy(ISO8601DateCoder())
        let dateModified: Date?

        @CodedBy(ISO8601DateCoder())
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
                name: meta.name,
                author: meta.author.name,
                version: meta.softwareVersion,
                ipdb: ipdbURL,
                features: features,
                navigations: []
            )
        }

        return nil
    }
}

extension VPUniverseScanner: ListScanner {
    func scanList(url: URL, content: String, kind: GameResourceKind) throws -> ListResult {
        let html = try SwiftSoup.parse(content)

        var pages: Int?
        var items = [ListResult.Item]()

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
        for item in try html.select("div.ipsDataItem_main h4 a") {
            let url = try item.attr("href")
            let title = try item.text()

            if url.contains("/tags/") {
                // sometimes they have nav by tag
                continue
            }

            if !url.isEmpty && !title.isEmpty, let url = URL(string: url) {
                items.append(.init(url: url, name: title))
            }
        }

        return .init(pages: pages, list: items)
    }
}
