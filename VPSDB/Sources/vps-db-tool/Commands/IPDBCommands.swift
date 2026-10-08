import ArgumentParser
import Foundation
import VPSDB

struct IPDBCommands: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "ipdb",
        abstract: "IPDB related commands",
        subcommands: [
            IPDBMissingCommand.self, IPDBVerifyCommand.self,
        ]
    )
}

struct IPDBMissingCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "missing",
        abstract: "show games with missing ipdb entries"
    )

    @OptionGroup var db: VPSDbArguments

    @Option(name: .long, help: "Path to ipdb.html")
    var ipdb: URL

    mutating func run() async throws {
        let db = try await db.database()
        let ipdb = try IPDB(html: self.ipdb)

        for game in db.games.all.sorted() {
            if game.ipdbUrl == nil && game.shouldHaveIPDBEntry {
                print("\(game.name), \(game.year ?? 0), \(game.manufacturer)")

                let entries = ipdb.byName[game.name] ?? []
                let filteredEntries: [IPDB.Entry]

                if entries.contains(where: { $0.manufacturer == game.manufacturer }) {
                    filteredEntries = entries.filter { $0.manufacturer == game.manufacturer }
                } else {
                    filteredEntries = entries
                }

                for entry in filteredEntries.sorted(by: { $0.year < $1.year }) {
                    var messages = [String]()
                    if game.players == nil {
                        messages.append("players: \(entry.players)")
                    }
                    if game.theme.isEmpty {
                        if !entry.themes.isEmpty {
                            messages.append(
                                "themes: \(entry.themes.map { $0.rawValue }.joined(separator: ", "))"
                            )
                        }
                    } else {
                        for theme in entry.themes {
                            if !game.theme.contains(theme) {
                                messages.append(
                                    "themes: \(entry.themes.map { $0.rawValue }.joined(separator: ", "))"
                                )
                                break
                            }
                        }
                    }
                    print(
                        "\t\(entry.id), \(entry.manufacturer), \(entry.year == 0 ? "" : entry.year.description) \(messages.joined(separator: ", "))"
                    )
                }
                print("")
            }
        }
    }
}

struct IPDBVerifyCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "verify",
        abstract: "show games that do not match ipdb entries"
    )

    @OptionGroup var db: VPSDbArguments

    @Option(name: .long, help: "Path to ipdb.html")
    var ipdb: URL

    mutating func run() async throws {
        let db = try await db.database()
        let ipdb = try IPDB(html: self.ipdb)

        for game in db.games.all.sorted() {
            if let ipdbId = game.ipdbId {
                if let entry = ipdb.entries[ipdbId] {
                    var messages = [String]()

                    if entry.name != game.name {
                        messages.append("name: \(game.name) does not match entry: \(entry.name)")
                    }
                    if entry.manufacturer != game.manufacturer {
                        messages.append(
                            "manufacturer: \(game.manufacturer) does not match entry: \(entry.manufacturer) (\(entry.manufacturerName))"
                        )
                    }
                    if entry.year != 0 && entry.year != game.year {
                        messages.append(
                            "year: \(game.year ?? 0) does not match entry: \(entry.year)")
                    }
                    if entry.players != game.players {
                        messages.append(
                            "players: \(game.players ?? 0) does not match entry: \(entry.players)")
                    }

                    if !messages.isEmpty {
                        print("\(game.name), \(game.year ?? 0), \(game.manufacturer), id=\(ipdbId)")
                        print("\t" + messages.joined(separator: "\n\t"))
                        print("")
                    }
                } else {
                    print(
                        "\(game.name), \(game.year ?? 0), \(game.manufacturer), id=\(ipdbId) -- no entry found for \(ipdbId)"
                    )

                    let entries = ipdb.byName[game.name] ?? []
                    for entry in entries.sorted(by: { $0.year < $1.year }) {
                        print(
                            "\t\(entry.id), \(entry.manufacturer), \(entry.year == 0 ? "" : entry.year.description)"
                        )
                    }

                    print("")
                }
            }
        }
    }
}
