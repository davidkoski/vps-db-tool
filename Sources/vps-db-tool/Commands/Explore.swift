import ArgumentParser
import Foundation

struct ExploreCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "explore",
        abstract: "A place to put exploration code"
    )

    @OptionGroup var db: VPSDbArguments

    mutating func run() async throws {
        let db = try db.database()

        print(
            """
            | Game | File | URL |
            | --- | ------ | -------- |
            """)

        var lines = [String]()

        func check(_ key: String, _ files: [any GameResource]) {
            for file in files {
                for url in file.urls {
                    if url.scheme == nil || url.host() == nil {
                        let g = db[file]!
                        lines.append("| \(g) | \(key) | \(url) |")
                    }
                }
            }
        }

        for game in db.games.all {
            check("tables", game.tables)
            check("b2s", game.backglasses)
            check("tutorials", game.tutorials)
            check("roms", game.roms)
            check("pupPacks", game.pupPacks)
            check("altColors", game.altColors)
            check("altSounds", game.altSounds)
            check("povs", game.povs)
            check("wheelArts", game.wheels)
            check("toppers", game.toppers)
            check("mediaPacks", game.mediaPacks)
            check("rules", game.rules)
        }
        print(lines.sorted().joined(separator: "\n"))
    }
}

struct CheckDuplicateURLs: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "explore",
        abstract: "A place to put exploration code"
    )

    @OptionGroup var db: VPSDbArguments

    mutating func run() async throws {
        let db = try db.database()

        print(
            """
            | URL | Game 1 | Game ... |
            | --- | ------ | -------- |
            """)

        var lines = [String]()
        for (url, tables) in db.tables.byURL {
            switch url.host {
            case "zenstudios.com", "www.pinballfx.com", "fss-pinball.com": continue
            default: break
            }
            if tables.count > 1 {
                func d(_ table: Table) -> String {
                    let g = db[table]!
                    return "\(g.name) (\(g.manufacturer) \(g.year!))"
                }
                lines.append(
                    "| \(url) | \(d(tables.first!)) | \(tables.dropFirst().map { d($0) }.joined(separator: ", ")) |"
                )
            }
        }
        print(lines.sorted().joined(separator: "\n"))
    }
}
