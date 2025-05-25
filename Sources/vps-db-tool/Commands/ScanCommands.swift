import ArgumentParser
import Foundation

struct ScanCommands: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "scan",
        abstract: "scanning related commands",
        subcommands: [
            DownloadCommand.self, CheckDownloadCommand.self, CheckMissingCommand.self,
            ScanPagesCommand.self,
        ]
    )
}

struct ScanArguments: ParsableArguments, Sendable {

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
    var url: URL?

    @Option
    var page = 1

    @Option
    var pages = 0

    @Flag
    var follow = false

    mutating func urls(scanner: ScanSources & ListScanner, client: HTTPClient) async throws -> [(
        ScanVariant, URL
    )] {
        var urls = [(ScanVariant, URL)]()

        if let url {
            self.site =
                switch vps_db_tool.Site(url) {
                case .vpu: .vpu
                case .vpf: .vpf
                default:
                    fatalError("site for \(url) not supported for scan")
                }

            if pages > 0 {
                for i in 0 ..< pages {
                    urls.append((.list, scanner.update(kind: kind, url: url, page: page + i)))
                }
            } else {
                urls.append((.list, url))
            }

        } else if pages > 0 {
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

struct DownloadCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "download",
        abstract: "download pages"
    )

    @OptionGroup var scan: ScanArguments

    mutating func run() async throws {
        let client = HTTPClient(cache: scan.cache, throttle: .seconds(3))
        let scanner = scan.site.scanner

        var first = true
        var urls = try await scan.urls(scanner: scanner, client: client)

        while !urls.isEmpty {
            let (variant, url) = urls.removeFirst()

            let content = try await client.getString(url)

            switch variant {
            case .detail:
                // nothing -- we just download
                print("\(url)")
            case .list:
                let result = try scanner.scanList(url: url, content: content, kind: scan.kind)
                if first {
                    first = false
                    print("\(scan.kind.rawValue): pages = \(result.pages ?? 0)")
                }

                print("\(url): count=\(result.list.count)")

                if scan.follow {
                    for item in result.list {
                        urls.append((.detail, item.url))
                    }
                }
            }
        }
    }
}

struct CheckDownloadCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "check",
        abstract: "check resources"
    )

    @OptionGroup var db: VPSDbArguments
    @OptionGroup var issues: IssuesArguments
    @OptionGroup var scan: ScanArguments

    @Flag(inversion: .prefixedEnableDisable)
    var interactive = true

    mutating func run() async throws {
        let db = try db.database()
        var issues = try issues.database()

        let client = HTTPClient(cache: scan.cache, throttle: .seconds(3))
        let scanner = scan.site.scanner

        var urls = try await scan.urls(scanner: scanner, client: client)

        while !urls.isEmpty {
            let (variant, url) = urls.removeFirst()

            let content = try await client.getString(url)

            switch variant {
            case .detail:
                break
            case .list:
                print(url)
                let result = try scanner.scanList(url: url, content: content, kind: scan.kind)

                for item in result.list {
                    if let match = db[scan.kind][item.url], let first = match.first {
                        if scan.follow, let game = db[first] {
                            try await checkDetails(
                                client: client, scanner: scanner, url: item.url,
                                game: game, items: match, issues: &issues)
                        }
                    } else {
                        var handled = false
                        if scan.follow {
                            let content = try await client.getString(item.url)
                            if let detail = try scanner.scanDetail(
                                url: item.url, content: content, kind: scan.kind)
                            {
                                let issue = URLIssue.entryNotFound(detail)
                                issues.report(kind: scan.kind, url: item.url, issue: issue)
                                handled = true
                            }
                        }
                        if !handled {
                            let issue = URLIssue.entryNotFound(item)
                            issues.report(kind: scan.kind, url: item.url, issue: issue)

                            // to auto obsolete
                            //                            switch item.author {
                            //                            case "tartzani", "remdwaas1986", "Onevox", "chokeee", "WED21", "hanibal2001", "gabrom78", "takut", "hauntfreaks", "Delta23", "dunriwikan45", "Javier15", "jbg4208", "senseless", "rothbauerw", "Sindbad":
                            //                                issues.report(kind: scan.kind, url: item.url, issue: issue, comment: "obsolete")
                            //                            default:
                            //                                issues.report(kind: scan.kind, url: item.url, issue: issue)
                            //                            }
                        }
                    }
                }
                print("")
            }
        }

        try self.issues.save(db: issues)
    }

    func checkDetails(
        client: HTTPClient, scanner: DetailScanner, url: URL, game: Game, items: [any Metadata],
        issues: inout IssueDatabase
    )
        async throws
    {
        let content = try await client.getString(url)
        let detail = try scanner.scanDetail(url: url, content: content, kind: scan.kind)

        if let detail {
            for item in items {
                if canonicalVersion(item.version) != canonicalVersion(detail.version) {
                    let issue = ResourceIssue.versionMismatch(detail.version)
                    issues.report(
                        game: game, kind: scan.kind, gameResource: item, url: url, issue: issue)
                }
            }
        } else {
            print("\(url): not able to parse details")
        }
    }
}

struct CheckMissingCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "check-missing",
        abstract: "check resources"
    )

    @OptionGroup var db: VPSDbArguments
    @OptionGroup var issues: IssuesArguments
    @OptionGroup var scan: ScanArguments

    @Flag var markdown = false

    mutating func run() async throws {
        let db = try db.database()
        let issues = try issues.database()

        let client = HTTPClient(cache: scan.cache, throttle: .seconds(3))
        let scanner = scan.site.scanner

        var urls = try await scan.urls(scanner: scanner, client: client)

        if markdown {
            print(
                """
                **Missing \(scan.kind)**

                | Name | Author | URL |
                | ---- | ------ | --- |                
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
                                print(
                                    "| \(item.name ?? "unknown") | \(item.author ?? "unknown" ) | \(item.url) |"
                                )
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

struct ScanPagesCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "pages",
        abstract: "scan pages and print matched resources"
    )

    @OptionGroup var db: VPSDbArguments
    @OptionGroup var scan: ScanArguments

    enum Output: String, Codable, ExpressibleByArgument {
        case url
        case game
        case file
    }

    @Option var output = Output.file

    mutating func run() async throws {
        let db = try db.database()

        let client = HTTPClient(cache: scan.cache, throttle: .seconds(3))
        let scanner = scan.site.scanner

        var urls = try await scan.urls(scanner: scanner, client: client)

        while !urls.isEmpty {
            let (variant, url) = urls.removeFirst()

            let content = try await client.getString(url)

            switch variant {
            case .detail:
                break
            case .list:
                let result = try scanner.scanList(url: url, content: content, kind: scan.kind)

                for item in result.list {
                    if let files = db[scan.kind][item.url], let first = files.first {
                        switch output {
                        case .url:
                            print(item.url)
                        case .game:
                            print(first.gameId)
                        case .file:
                            print(first.id)
                        }
                    }
                }
            }
        }
    }
}
