import Foundation
import ArgumentParser

struct QueryCommands: AsyncParsableCommand {
    
    static let configuration = CommandConfiguration(
        commandName: "query",
        abstract: "Query vps-db"
    )

    @OptionGroup var db: VPSDbArguments
    
    @Option var kind: GameResourceKind = .table

    mutating func run() async throws {
        let db = try db.database()
    }
}
