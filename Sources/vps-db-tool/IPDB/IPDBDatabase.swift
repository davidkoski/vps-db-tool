import Foundation
import SwiftSoup

struct IPDB: Sendable {

    struct Entry: Codable, Sendable {
        let id: String
        let name: String
        let manufacturer: Manufacturer
        let manufacturerName: String
        let year: Int
        let players: Int
        let kind: Kind?
        let themes: Set<Theme>
    }

    let entries: [String: Entry]
    let byName: [String: [Entry]]
}

extension IPDB {

    init(html url: URL) throws {
        let html = try SwiftSoup.parse(String(contentsOf: url, encoding: .utf8))

        var entries = [String: Entry]()

        for row in try html.select("tr").dropFirst() {
            /*
             <td>
                 <a href="machine.cgi?gid=2539&puid=44280">"300"</a>
             </td>
             <td>D. Gottlieb & Company</td>
             <td>August, 1975</td>
             <td>4</td>
             <td>EM</td>
             <td>Sports - Bowling</td>
             */
            var name = ""
            var id = ""
            var manufacturer: Manufacturer = .unknown
            var manufacturerName = ""
            var year = 0
            var players = 0
            var kind: Kind?
            var themes = Set<Theme>()

            if let link = try row.select("a").first() {
                name = try link.text()
                let url = try link.attr("href")
                if let components = URLComponents(string: url) {
                    if let gid = components.queryItems?.filter({ $0.name == "gid" }).first {
                        id = gid.value ?? ""
                    }
                }

                let cols = try row.select("td")
                manufacturerName = try cols[1].text()
                if let v = Manufacturer(string: manufacturerName) {
                    manufacturer = v
                }
                let yearString = try cols[2].text()
                year =
                    Int(
                        yearString
                            .split(separator: ",")
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { $0.hasPrefix("19") || $0.hasPrefix("20") }
                            .first ?? "") ?? 0

                players = Int(try cols[3].text()) ?? 0

                kind = Kind(rawValue: try cols[4].text())

                themes = Set(
                    try cols[5].text().split(separator: " - ")
                        .compactMap { Theme(rawValue: String($0)) })
            }

            let entry: IPDB.Entry = .init(
                id: id,
                name: name,
                manufacturer: manufacturer,
                manufacturerName: manufacturerName,
                year: year,
                players: players,
                kind: kind,
                themes: themes
            )

            entries[id] = entry
        }

        self.entries = entries
        self.byName = Dictionary(grouping: entries.values, by: \.name)
    }

}
