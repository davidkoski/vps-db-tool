import ArgumentParser
import Foundation
import VPSDB

struct ScanCommands: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "scan",
        abstract: "scanning related commands",
        subcommands: [
            DownloadCommand.self, CheckDownloadCommand.self, CheckMissingCommand.self,
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
        case nirvana

        var site: VPSDB.Site {
            switch self {
            case .vpu: .vpu
            case .vpf: .vpf
            case .nirvana: .pinballnirvana
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
    var pages = 1

    @Flag
    var follow = false

    func requests() -> [ListScanRequest] {
        if let url {
            return ListScanRequest.pages(1 ... pages, url, kind)
        } else {
            return ListScanRequest.pages(1 ... pages, site: site.site, kind)
        }
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

        let follow = scan.follow
        let stream = gather(
            client: client, maxAge: .seconds(3600), requests: scan.requests(), suppress: [:]
        ) { _ in
            follow
        }

        for try await item in stream {
            print("\(item.name): \(item.url)")
        }
    }
}

struct CheckDownloadCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "check",
        abstract: "check resources"
    )

    @OptionGroup var db: VPSDbArguments
    @OptionGroup var scan: ScanArguments

    @Flag(inversion: .prefixedEnableDisable)
    var interactive = true

    mutating func run() async throws {
        let suppressedURLs = try db.suppressedURLs()
        let db = try await db.database()

        let client = HTTPClient(cache: scan.cache, throttle: .seconds(3))
        let follow = scan.follow
        let stream = gather(
            client: client, maxAge: .seconds(3600), requests: scan.requests(),
            suppress: suppressedURLs
        ) { _ in
            follow
        }

        for try await item in stream {
            print("\(item.name): \(item.url)")

            if let match = db[scan.kind][item.url], let first = match.first {
                if scan.follow, let game = db[first] {
                    try await checkDetails(
                        client: client, request: item.detailRequest,
                        db: db, game: game, items: match,
                        suppressedURLs: suppressedURLs)
                }
            } else {
                var handled = false
                if scan.follow {
                    let content = try await client.getString(item.url)
                    let request = item.detailRequest
                    if let detail = try await request.scan(content: content) {
                        var show = true
                        if let reason = suppressedURLs[detail.url] {
                            show = reason.shouldSuppress(detail: detail, db: db)
                        }
                        if show {
                            print(
                                "\(scan.kind.rawValue): not found \(item.url)\n\t\(detail)")
                        }
                        handled = true
                    }
                }
                if !handled {
                    var show = true
                    if let reason = suppressedURLs[item.url] {
                        show = reason.shouldSuppress(detail: item, db: db)
                    }
                    if show {
                        print("\(scan.kind.rawValue): not found \(item.url)\n\t\(item)")
                    }

                    // to auto obsolete
                    //                            switch item.author {
                    //                            case "tartzani", "remdwaas1986", "Onevox", "chokeee", "WED21", "hanibal2001", "gabrom78", "takut", "hauntfreaks", "Delta23", "dunriwikan45", "Javier15", "jbg4208", "senseless", "rothbauerw", "Sindbad":
                    //                                issues.report(kind: scan.kind, url: item.url, issue: issue, comment: "obsolete")
                    //                            default:
                    //                                issues.report(kind: scan.kind, url: item.url, issue: issue)
                    //                            }
                }
            }

            print("")
        }
    }

    func checkDetails(
        client: HTTPClient, request: DetailScanRequest,
        db: Database, game: Game, items: [any Metadata],
        suppressedURLs: [URL: SuppressionReason]
    )
        async throws
    {
        let content = try await client.getString(request.url)
        let detail = try await request.scan(content: content)

        if let detail {
            for item in items {
                var show = true
                if let reason = suppressedURLs[detail.url] {
                    show = reason.shouldSuppress(detail: detail, db: db)
                }
                if show, canonicalVersion(item.version) != canonicalVersion(detail.version) {
                    print(
                        "\(game) \(scan.kind.rawValue) \(item.id): version mismatch \(canonicalVersion(item.version)) != \(canonicalVersion(detail.version))"
                    )
                }
            }
        } else {
            print("\(request.url): not able to parse details")
        }
    }
}

struct CheckMissingCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "check-missing",
        abstract: "check resources"
    )

    @OptionGroup var db: VPSDbArguments
    @OptionGroup var scan: ScanArguments

    enum Output: String, ExpressibleByArgument {
        case markdown
        case csv
        case report
    }

    @Option var output: Output = .markdown

    mutating func run() async throws {
        let suppressedURLs = try db.suppressedURLs()
        let db = try await db.database()

        let client = HTTPClient(cache: scan.cache, throttle: .seconds(3))
        let follow = scan.follow
        let stream = gather(
            client: client, maxAge: .seconds(3600), requests: scan.requests(),
            suppress: suppressedURLs
        ) { _ in
            follow
        }

        switch output {
        case .markdown:
            print(
                """
                **Missing \(scan.kind)**

                | Name | Author | URL |
                | ---- | ------ | --- |                
                """
            )
        case .csv:
            print("name\tauthor\tversion\tdate\turl")
        case .report:
            break
        }

        for try await item in stream {
            if db[scan.kind][item.url] == nil {
                var show = true
                if let reason = suppressedURLs[item.url] {
                    show = reason.shouldSuppress(detail: item, db: db)
                }

                if show {
                    switch output {
                    case .markdown:
                        print(
                            "| \(item.name) | \(item.author ) | \(item.url) |"
                        )
                    case .csv:
                        print(
                            "\(item.name)\t\(item.author)\t\(item.version ?? "1.0")\t\(item.date.timeIntervalSince1970)\t\(item.url)"
                        )
                    case .report:
                        print("\(scan.kind.rawValue): not found \(item.url)\n\t\(item)")
                    }
                }
            }
        }
    }
}
