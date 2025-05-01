import ArgumentParser
import Foundation

struct ScanCommands: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "scan",
        abstract: "scanning related commands",
        subcommands: [
            DownloadCommand.self, CheckDownloadCommand.self,
        ]
    )
}

struct ScanArguments: ParsableArguments, Sendable {

    @Option
    var cache: URL

    @Option
    var kind: GameResourceKind = .table

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

struct DownloadCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "download",
        abstract: "download pages"
    )

    @OptionGroup var scan: ScanArguments

    mutating func run() async throws {
        let client = HTTPClient(cache: scan.cache, throttle: .seconds(3))
        let scanner = VPUniverseScanner()

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
    @OptionGroup var scan: ScanArguments

    mutating func run() async throws {
        let db = try db.database()

        let client = HTTPClient(cache: scan.cache, throttle: .seconds(3))
        let scanner = VPUniverseScanner()

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
                    if let match = db[scan.kind][item.url] {
                        if scan.follow {
                            try await checkDetails(
                                client: client, scanner: scanner, url: item.url, items: match)
                        }
                    } else {
                        print("Not Found: \(item.name) - \(item.url)")
                        if let games = db.gamesByName[item.name] {
                            for game in games {
                                if game[scan.kind].isEmpty {
                                    print(
                                        "\t\(game.name) \(game.manufacturer) (\(game.year ?? 0)): empty \(scan.kind)"
                                    )
                                }
                            }
                        }
                        if scan.follow {
                            try await printDetails(client: client, scanner: scanner, url: item.url)
                            print("")
                        }
                    }
                }
                print("")
            }
        }
    }

    func printDetails(client: HTTPClient, scanner: DetailScanner, url: URL) async throws {
        let content = try await client.getString(url)
        if let detail = try scanner.scanDetail(url: url, content: content, kind: scan.kind) {
            print("\t\(detail.name ?? "-"), \(detail.author ?? "-"), \(detail.version ?? "-")")
            if let ipdb = detail.ipdb {
                print("\t\(ipdb)")
            }
            if !detail.features.isEmpty {
                print("\t\(detail.features.map { $0.rawValue }.sorted().joined(separator: ", "))")
            }
        }
    }

    func checkDetails(client: HTTPClient, scanner: DetailScanner, url: URL, items: [any Metadata])
        async throws
    {
        let content = try await client.getString(url)
        let detail = try scanner.scanDetail(url: url, content: content, kind: scan.kind)

        func canonicalVersion(_ string: String?) -> String {
            (string ?? "")
                .replacingOccurrences(of: "v", with: "")
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: ".0.0", with: ".0")
        }

        if let detail {
            for item in items {
                var messages = [String]()
                if canonicalVersion(item.version) != canonicalVersion(detail.version) {
                    messages.append("Version: \(item.version ?? "-") != \(detail.version ?? "-")")
                }

                if !messages.isEmpty {
                    print(url)
                    print(
                        "\(item.gameName) - \(item.gameId) - \(detail.name ?? ""): \(messages.joined(separator: ", "))"
                    )
                    print("")
                }
            }
        } else {
            print("\(url): not able to parse details")
        }
    }
}
