import ArgumentParser
import Foundation

struct ReportCommands: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "scan",
        abstract: "scanning related commands",
        subcommands: [
            DownloadCommand.self, CheckDownloadCommand.self, CheckMissingCommand.self,
        ]
    )
}

struct ReportArguments: ParsableArguments, Sendable {

    @Option
    var cache = URL(fileURLWithPath: "./cache")

    @Option
    var kind: GameResourceKind = .table

    enum Site: String, ExpressibleByArgument {
        case vpu
        case vpf

        var scanner: ScanSources & DetailScanner & ListScanner {
            switch self {
            case .vpu: VPUniverseScanner()
            case .vpf: VPForumsScanner()
            }
        }
    }

    @Option
    var site = Site.vpu

    @Option
    var page = 1

    @Option
    var pages = 0

    @Flag
    var follow = false

    func urls(scanner: ScanSources & ListScanner, client: HTTPClient) async throws -> [(
        ScanVariant, URL
    )] {
        var urls = [(ScanVariant, URL)]()

        if pages > 0 {
            for root in scanner.sources(kind: kind) {
                let content = try await client.getString(root)
                let list = try scanner.scanList(url: root, content: content, kind: kind)

                for i in 0 ..< min(pages, list.pages ?? pages) {
                    urls.append((.list, scanner.update(kind: kind, url: root, page: page + i)))
                }
            }
        } else {
            urls.append(contentsOf: scanner.sources(kind: kind).map { (.list, $0) })
        }

        return urls
    }
}

struct ReportCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "check-missing",
        abstract: "check resources"
    )

    @OptionGroup var db: VPSDbArguments
    @OptionGroup var issues: IssuesArguments
    @OptionGroup var scan: ReportArguments

    @Flag var markdown = false

    mutating func run() async throws {
        let db = try db.database()
        var issues = try issues.database()

        let client = HTTPClient(cache: scan.cache, throttle: .seconds(3))
        let scanner = scan.site.scanner

        var urls = try await scan.urls(scanner: scanner, client: client)

        if markdown {
            print(
                """
                **Missing \(scan.kind)**

                | Name | URL |
                | ---- | --- |                
                """
            )
        }

        while !urls.isEmpty {
            let (variant, url) = urls.removeFirst()

            let content = try await client.getString(url)

            switch variant {
            case .detail:
                break
            case .list:
                let result = try scanner.scanList(url: url, content: content, kind: scan.kind)

                for item in result.list {
                    if db[scan.kind][item.url] == nil {
                        let issue = URLIssue.entryNotFound(item)
                        if !issues.check(kind: scan.kind, url: item.url, issue: issue) {
                            if markdown {
                                print("| \(item.name ?? "unknown") | \(item.url) |")
                            } else {
                                print(issue.describe(kind: scan.kind, url: item.url))
                            }
                        }
                    }
                }
            }
        }

        try self.issues.save(db: issues)
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
        <script src="https://cdn.datatables.net/2.3.0/js/dataTables.min.js"></script>
        <script src="https://code.jquery.com/jquery-3.7.1.min.js"></script>
        <link href="https://cdn.datatables.net/2.3.0/css/dataTables.dataTables.min.css" rel="stylesheet"></link>
        """

}
