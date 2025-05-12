import ArgumentParser
import Foundation

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
        let db = try db.database()
        var issues = try issues.database()
        let client = HTTPClient(cache: cache, throttle: .seconds(3))

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
                        let content = try await client.getString(item.url)
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
                                            url: item.url, name: item.name ?? "unknown", kind: kind,
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
                                url: item.url, name: item.name ?? "unknown", kind: kind,
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
    let kind: GameResourceKind
    let issue: String
}

private struct Report {

    let header =
        """
        <script src="https://code.jquery.com/jquery-3.7.1.min.js"></script>
        <script src="https://cdn.datatables.net/2.3.0/js/dataTables.min.js"></script>
        <link href="https://cdn.datatables.net/2.3.0/css/dataTables.dataTables.min.css" rel="stylesheet"></link>
        """

    func emit(items: [Item]) -> String {
        header + """
            <table id="report" class="display">
            <thead>
                <tr>
                    <th>URL</th>
                    <th>Site</th>
                    <th>Kind</th>
                    <th>Name</th>
                    <th>Issue</th>
                </tr>
            </thead>
            """ + items.map { emitRow($0) }.joined(separator: "\n") + """
                </table>
                <script>
                $("#report").DataTable({
                    paging:   false,
                    info:     false,
                    searching: true,
                    order: [],
                });
                </script>
                """
    }

    private func emitRow(_ item: Item) -> String {
        """
        <tr>
            <td><a href="\(item.url)">\(item.url)</a></td>
            <td>\(Site(item.url).rawValue)</td>
            <td>\(item.kind.rawValue)</td>
            <td>\(item.name)</td>
            <td>\(item.issue)</td>
        </tr>
        """
    }
}
