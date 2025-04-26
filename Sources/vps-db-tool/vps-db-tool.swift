import ArgumentParser
import Foundation

@main
struct VPSDbTool: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Command line tool to assist withvps-db",
        subcommands: [
            DownloadCommand.self, CheckVersionCommand.self, ExploreCommand.self,
        ]
    )
}

struct VPSDbArguments: ParsableArguments, Sendable {

    @Option(name: .customLong("db"), help: "Path to vpsdb.json")
    var path: URL = URL(filePath: "../db/vpsdb.json")

    private var db: Database?

    mutating func database() throws -> Database {
        if let db {
            return db
        }

        let db = try JSONDecoder().decode(Database.self, from: Data(contentsOf: path))
        self.db = db
        return db
    }
}

struct DownloadCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "download",
        abstract: "XXX"
    )

    @OptionGroup var db: VPSDbArguments

    mutating func run() async throws {
        let db = try db.database()

        //        print(db.games.reduce(0) { $0 + $1.tables.count })
        //        print(db.games.map { "\($0.name) \($0.tables.count)" }.joined(separator: "\n"))
    }
}
