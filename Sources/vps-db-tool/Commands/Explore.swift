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

        for game in db.games.all {
            if game.manufacturer == .williams && game.designers.isEmpty {
                print(game.name)
            }
        }
    }
}
