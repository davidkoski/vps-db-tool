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

        func id(_ s: String) -> String {
            (s.first!.lowercased() + s.dropFirst())
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "-", with: "")
        }

        //        print(
        //            Set(db.games.all.flatMap { $0.tables }.flatMap { $0.features }).sorted()
        //                .map { "case \(id($0.name)) = \"\($0.name)\"" }
        //                .joined(separator: "\n")
        //        )
    }
}
