import Foundation
import SwiftSoup

public struct IPDB: Sendable {

    public struct Entry: Codable, Sendable {
        public let id: String
        public let name: String
        public let manufacturer: Manufacturer
        public let manufacturerName: String
        public let year: Int
        public let players: Int
        public let kind: Kind?
        public let themes: Set<Theme>
    }

    public let entries: [String: Entry]
    public let byName: [String: [Entry]]
}

extension IPDB {

    public init() {
        entries = [:]
        byName = [:]
    }

    public init(html url: URL) throws {
        let data = try Data(contentsOf: url)
        let str = data.withUnsafeBytes { ptr in
            let (s, _) = String.decodeCString(ptr, as: UTF8.self, repairingInvalidCodeUnits: true)!
            return s
        }
        let html = try SwiftSoup.parse(str)

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

    public func search(name: String, manufacturer: Manufacturer?, year: Int?) -> [Entry] {

        func canonicalize(_ string: String) -> String {
            String(string.lowercased().filter { $0.isLetter || $0.isNumber })
        }

        let name = canonicalize(name)

        return entries
            .values
            .filter { entry in
                var match = false
                let entryName = canonicalize(entry.name)
                if entryName.contains(name) || name.contains(entryName) {
                    match = true
                }
                if match, let manufacturer, entry.manufacturer != manufacturer {
                    match = false
                }
                if match, let year, entry.year != year {
                    match = false
                }
                return match
            }
            .sorted {
                ($0.name, $0.year, $0.id) < ($1.name, $1.year, $1.id)
            }
    }
}
