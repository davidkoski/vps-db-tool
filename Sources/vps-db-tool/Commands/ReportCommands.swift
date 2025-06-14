import ArgumentParser
import Foundation
import VPSDB

struct ReportCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "report",
        abstract: "write missing resource report"
    )

    @OptionGroup var db: VPSDbArguments
    @OptionGroup var issues: IssuesArguments

    @Option var cache = URL(fileURLWithPath: "./cache-report")

    @Option var output = URL(fileURLWithPath: "./report/index.html")

    @Flag var recordIssues = false

    mutating func run() async throws {
        let scans: [(Site, GameResourceKind, Bool)] = [
            (.vpu, .table, true),
            (.vpf, .table, true),
            (.vpu, .b2s, false),
            (.vpf, .b2s, false),
            (.vpu, .rom, false),
            (.vpf, .rom, false),
            (.vpu, .pupPack, false),
            (.vpu, .altColor, false),
            (.vpu, .altSound, false),
            (.vpu, .pov, false),
            (.vpu, .wheelArt, false),
            (.vpf, .wheelArt, false),
            (.vpu, .topper, false),
            (.vpf, .topper, false),
            (.vpu, .mediaPack, false),
            (.vpf, .mediaPack, false),
            (.vpu, .rule, false),
        ]

        var items = [Item]()

        for s in scans {
            try await items.append(contentsOf: scan(site: s.0, kind: s.1, follow: s.2))
        }

        if !items.isEmpty {
            try Report().emit(items: items).write(to: output, atomically: true, encoding: .utf8)
        }
    }

    private mutating func scan(
        site: Site, kind: GameResourceKind, follow: Bool = false
    ) async throws -> [Item] {
        let db = try await db.database()
        var issues = try issues.database()
        let client = HTTPClient(cache: cache, throttle: .seconds(2))

        let scanner: ScanSources & DetailScanner & ListScanner =
            switch site {
            case .vpu: VPUniverseScanner()
            case .vpf: VPForumsScanner()
            case .pinballnirvana, .other: fatalError()
            }

        print(site, kind)

        var result = [Item]()

        for listURL in scanner.sources(kind: kind) {
            print(listURL)

            let content = try await client.getString(listURL, bypassCache: true)

            let scanResult = try scanner.scanList(url: listURL, content: content, kind: kind)

            for item in scanResult.list {
                print(item.name ?? "unknown")
                if let match = db[kind][item.url], let file = match.first, let game = db[file] {
                    if follow {
                        print(item.url)
                        let content = try await client.getString(item.url, bypassCache: true)
                        if let detail = try scanner.scanDetail(
                            url: item.url, content: content, kind: kind)
                        {

                            if canonicalVersion(file.version) != canonicalVersion(detail.version) {
                                let issue = ResourceIssue.versionMismatch(detail.version)

                                var report = !issues.check(
                                    game: game, kind: kind, gameResource: file, url: item.url,
                                    issue: issue)

                                if report && recordIssues {
                                    report =
                                        issues.report(
                                            game: game, kind: kind, gameResource: file,
                                            url: item.url, issue: issue) == .willFix
                                }

                                if report {
                                    result.append(
                                        .init(
                                            url: item.url, name: item.name ?? "unknown",
                                            author: item.author ?? "unknown", kind: kind,
                                            issue:
                                                "version mismatch: \(canonicalVersion(file.version)) vs \(canonicalVersion(detail.version))"
                                        ))
                                }
                            }
                        }
                    }
                } else {
                    let issue = URLIssue.entryNotFound(item)
                    if !issues.check(kind: kind, url: item.url, issue: issue) {
                        result.append(
                            .init(
                                url: item.url, name: item.name ?? "unknown",
                                author: item.author ?? "unknown", kind: kind,
                                issue: "missing"
                            ))
                    }
                }
            }
        }

        self.issues.update(issues)

        return result
    }
}

private struct Item {
    let url: URL
    let name: String
    let author: String
    let kind: GameResourceKind
    let issue: String
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
                        <th>URL</th>
                        <th>Name</th>
                        <th>Author</th>
                        <th>Site</th>
                        <th>Kind</th>
                        <th>Issue</th>
                    </tr>
                </thead>
                """ + items.map { emitRow($0) }.joined(separator: "\n") + """
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
