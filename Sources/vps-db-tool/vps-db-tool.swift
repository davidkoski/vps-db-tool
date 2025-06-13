import ArgumentParser
import Foundation
import VPSDB

@main
struct VPSDbTool: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Command line tool to assist withvps-db",
        subcommands: [
            DownloadCommand.self, CheckCommands.self, ExploreCommand.self,
            IPDBCommands.self, ScanCommands.self, EditCommands.self,
            IssueCommands.self, ReportCommand.self,
        ]
    )
}

struct VPSDbArguments: ParsableArguments, Sendable {

    @Option(name: .customLong("db"), help: "Path to vpsdb.json")
    var path: URL = URL(fileURLWithPath: "../vps-db/db/vpsdb.json")

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

struct IssuesArguments: ParsableArguments, Sendable {

    @Option(name: .customLong("issues"), help: "Path to issues.json")
    var path: URL = URL(fileURLWithPath: "issues.json")

    private var db: IssueDatabase?

    mutating func database() throws -> IssueDatabase {
        if let db {
            return db
        }

        let db = try JSONDecoder().decode(IssueDatabase.self, from: Data(contentsOf: path))
        self.db = db
        return db
    }

    mutating func update(_ db: IssueDatabase) {
        self.db = db
    }

    func save(db: IssueDatabase) throws {
        try JSONEncoder().encode(db).write(to: path, options: .atomic)
    }
}
