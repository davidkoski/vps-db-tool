import Foundation
import ArgumentParser

struct ExploreCommand: AsyncParsableCommand {
    
    static let configuration = CommandConfiguration(
        commandName: "explore",
        abstract: "A place to put exploration code"
    )

    @OptionGroup var db: VPSDbArguments

    mutating func run() async throws {
        let db = try db.database()
        
        for table in db.tables.all {
            if table.site == .other {
                if let game = db.games[table.gameId] {
                    print("\(game.name)\t\(game.id)\t\(table.url?.description ?? "None")")
                }
            }
        }
    }
}
