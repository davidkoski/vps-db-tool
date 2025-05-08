import ArgumentParser
import Foundation

struct CheckCommands: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "check",
        abstract: "various check commands (local db)",
        subcommands: [
            CheckTableFormat.self, CheckYear.self,
            CheckTheme.self, CheckMod.self, CheckRetheme.self,
        ]
    )
}

struct CheckTableFormat: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "table-format",
        abstract: "Check table format"
    )

    @OptionGroup var db: VPSDbArguments

    mutating func run() async throws {
        let db = try db.database()

        for g in db.games.all.sorted() {
            for t in g.tables {
                if t.tableFormat == nil {
                    print("\(g) \(t.url)")
                }
            }
        }
    }
}

struct CheckYear: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "year",
        abstract: "Check year"
    )

    @OptionGroup var db: VPSDbArguments

    mutating func run() async throws {
        let db = try db.database()

        for g in db.games.all.sorted() {
            if g.year == nil || g.year == 0 {
                print(g)
            }
        }
    }
}

struct CheckTheme: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "theme",
        abstract: "Check theme"
    )

    @OptionGroup var db: VPSDbArguments

    mutating func run() async throws {
        let db = try db.database()

        for g in db.games.all.sorted() {
            if g.theme.isEmpty {
                print(g)
            }
        }
    }
}

struct CheckMod: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "mod",
        abstract: "Check missing Mod"
    )

    @OptionGroup var db: VPSDbArguments

    mutating func run() async throws {
        let db = try db.database()

        for g in db.games.all.sorted() {
            for t in g.tables {
                if !t.features.contains(.mod) && t.gameResource.authors.count > 1 {
                    print("\(g) \(t.url)")
                }
            }
        }
    }
}

struct CheckRetheme: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "retheme",
        abstract: "Check missing Retheme"
    )

    @OptionGroup var db: VPSDbArguments

    mutating func run() async throws {
        let db = try db.database()

        for g in db.games.all.sorted() {
            for t in g.tables {
                if let comment = t.gameResource.comment {
                    if comment.contains("Retheme") || comment.contains("Reskin") {
                        if !t.features.contains(.retheme) {
                            print("\(g) \(t.url)")
                        }
                    }
                }
            }
        }
    }
}
