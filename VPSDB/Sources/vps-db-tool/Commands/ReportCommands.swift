import ArgumentParser
import Foundation
import Logging
import VPSDB

private let log = Logger(label: "Report")

struct ReportCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "report",
        abstract: "write missing resource report"
    )

    @OptionGroup var db: VPSDbArguments

    @Option var cache = URL(fileURLWithPath: "./cache-report")

    @Option var output = URL(fileURLWithPath: "./report/index.html")

    mutating func run() async throws {
        let scans: [(GameResourceKind, Bool)] = [
            (.table, true),
            (.b2s, false),
            (.rom, false),
            (.pupPack, false),
            (.altColor, false),
            (.altSound, false),
            (.pov, false),
            (.wheelArt, false),
            (.topper, false),
            (.mediaPack, false),
            (.rule, false),
        ]

        var items = [Item]()

        // make sure these load cleanly
        _ = try await db.database()

        for s in scans {
            log.info("BEGIN SCAN \(s.0) follow=\(s.1)")
            do {
                let scanResults = try await scan(kind: s.0, follow: s.1)
                items.append(contentsOf: scanResults)
                log.info("END SCAN \(s.0) ok")
            } catch {
                log.error(
                    "Error scanning \(s.0): \(type(of: error)) \(String(reflecting: error))"
                )
                log.info("END SCAN \(s.0) failed")
                throw error
            }
        }

        if !items.isEmpty {
            try Report().emit(items: items).write(to: output, atomically: true, encoding: .utf8)
        }
    }

    private func getVersion(
        client: HTTPClient, kind: GameResourceKind, scanner: DetailScanner, item: DetailResult
    ) async throws -> String? {
        log.info("getVersion: \(item.url)")
        let content = try await client.getString(item.url, bypassCache: true)
        if let detail = try scanner.scanDetail(
            url: item.url, content: content, kind: kind)
        {
            return detail.version
        }
        return nil
    }

    fileprivate func fetch(
        _ client: HTTPClient, _ kind: GameResourceKind,
        _ scanner: any DetailScanner & ListScanner & ScanSources, _ item: DetailResult
    ) async -> String? {
        do {
            return try await getVersion(
                client: client, kind: kind, scanner: scanner, item: item)
        } catch {
            log.error(
                "Error fetching \(item.url): \(type(of: error)) \(String(reflecting: error))")
            return "failed"
        }
    }

    private mutating func scan(
        kind: GameResourceKind, follow: Bool = false
    ) async throws -> [Item] {
        let suppressedURLs = try db.suppressedURLs()
        let db = try await db.database()

        @Sendable
        func followItem(_ item: DetailResult) -> Bool {
            guard follow else { return false }

            if let reason = suppressedURLs[item.url] {
                if reason.shouldSuppress() {
                    return false
                }
            }

            if let match = db.existing(url: item.normalizedURL, kind: kind),
                let file = match.first, let game = db[file]
            {
                // if we matched an existing file and want to folow links
                // to check version
                return true
            }

            return false
        }

        let client = HTTPClient(cache: cache, throttle: .seconds(2))
        let details = try await withThrowingTaskGroup { group in
            for site in Site.scanSites {
                group.addTask {
                    let stream = gather(
                        client: client, maxAge: .seconds(3600), site: site,
                        kind: kind, suppress: [:], follow: followItem(_:))

                    var result = [DetailResult]()
                    for await item in stream {
                        result.append(item)
                    }
                    return result
                }
            }
            var results = [DetailResult]()
            for try await result in group {
                results.append(contentsOf: result)
            }
            return results
        }

        var result = [Item]()

        for item in details {
            if let reason = suppressedURLs[item.url] {
                if reason.shouldSuppress(detail: item, db: db) {
                    continue
                }
            }

            if let match = db.existing(url: item.normalizedURL, kind: kind),
                let file = match.first, let game = db[file]
            {
                if item.version == nil { continue }

                // matches an existing item, check the version
                if canonicalVersion(file.version) != canonicalVersion(item.version) {
                    result.append(
                        .init(
                            url: item.normalizedURL, name: item.name,
                            author: item.author, kind: kind,
                            issue:
                                "version mismatch: \(canonicalVersion(file.version)) vs \(canonicalVersion(item.version))",
                            date: item.date
                        ))
                } else {
                    // no version mismatch, nothing to report
                }
            } else {
                // no existing file, report as missing
                result.append(
                    .init(
                        url: item.normalizedURL, name: item.name,
                        author: item.author, kind: kind,
                        issue: "missing",
                        date: item.date
                    ))
            }
        }

        log.info("SCAN END \(kind) result=\(result.count)")

        return result
    }
}

private struct Item: Comparable {
    let url: URL
    let name: String
    let author: String
    let kind: GameResourceKind
    let issue: String
    let date: Date

    static func < (lhs: Item, rhs: Item) -> Bool {
        lhs.date > rhs.date
    }
}

private struct Report {

    // tabs from: https://www.w3schools.com/howto/howto_js_tabs.asp

    let header =
        """
        <script src="https://code.jquery.com/jquery-3.7.1.min.js"></script>
        <script src="https://cdn.datatables.net/2.3.0/js/dataTables.min.js"></script>
        <link href="https://cdn.datatables.net/2.3.0/css/dataTables.dataTables.min.css" rel="stylesheet"></link>
        <style>
        /* Style the tab */
        .tab {
          overflow: hidden;
          border: 1px solid #ccc;
          background-color: #f1f1f1;
        }

        /* Style the buttons that are used to open the tab content */
        .tab button {
          background-color: inherit;
          float: left;
          border: none;
          outline: none;
          cursor: pointer;
          padding: 14px 16px;
          transition: 0.3s;
        }

        /* Change background color of buttons on hover */
        .tab button:hover {
          background-color: #ddd;
        }

        /* Create an active/current tablink class */
        .tab button.active {
          background-color: #ccc;
        }

        /* Style the tab content */
        .tabcontent {
          display: none;
          padding: 6px 12px;
          border: 1px solid #ccc;
          border-top: none;
        }
        </style>
        <script>
        function switchTab(evt, tabName) {
          // Declare all variables
          var i, tabcontent, tablinks;

          // Get all elements with class="tabcontent" and hide them
          tabcontent = document.getElementsByClassName("tabcontent");
          for (i = 0; i < tabcontent.length; i++) {
            tabcontent[i].style.display = "none";
          }

          // Get all elements with class="tablinks" and remove the class "active"
          tablinks = document.getElementsByClassName("tablinks");
          for (i = 0; i < tablinks.length; i++) {
            tablinks[i].className = tablinks[i].className.replace(" active", "");
          }

          // Show the current tab, and add an "active" class to the button that opened the tab
          document.getElementById(tabName).style.display = "block";
          evt.currentTarget.className += " active";
        }
        </script>
        <h4>Built \(Date().formatted())</h4>

        """

    func emit(items: [Item]) -> String {
        var result = header
        let itemsByKind = Dictionary(grouping: items, by: \.kind)

        result +=
            """
            <div class="tab">

            """
        for (i, (kind, items)) in itemsByKind.sorted(by: { $0.key < $1.key }).enumerated() {
            result +=
                """
                <button class="tablinks\(i == 0 ? " active" : "")" onclick="switchTab(event, '\(kind)')">\(kind) (\(items.count))</button>

                """
        }
        result +=
            """
            </div>

            """

        for (i, (kind, items)) in itemsByKind.sorted(by: { $0.key < $1.key }).enumerated() {
            result +=
                """
                <div id="\(kind)" class="tabcontent"\(i == 0 ? " style=\"display: block;\"" : "")>
                <h3>\(kind)</h3>
                <table id="report\(kind)" class="display">
                <thead>
                    <tr>
                        <th>Date</th>
                        <th>URL</th>
                        <th>Name</th>
                        <th>Author</th>
                        <th>Site</th>
                        <th>Kind</th>
                        <th>Issue</th>
                    </tr>
                </thead>
                """ + items.sorted().map { emitRow($0) }.joined(separator: "\n") + """
                    </table>
                    <script>
                    $("#report\(kind)").DataTable({
                        paging:   false,
                        info:     false,
                        searching: true,
                        order: [],
                    });
                    </script>
                    </div>

                    """

        }

        return result
    }

    private func emitRow(_ item: Item) -> String {
        """
        <tr>
            <td>\(item.date.formatted(date: .abbreviated, time: .omitted))</td>
            <td><a href="\(item.url)" target="_blank">\(item.url)</a></td>
            <td>\(item.name)</td>
            <td>\(item.author)</td>
            <td>\(Site(item.url).rawValue)</td>
            <td>\(item.kind.rawValue)</td>
            <td>\(item.issue)</td>
        </tr>
        """
    }
}
