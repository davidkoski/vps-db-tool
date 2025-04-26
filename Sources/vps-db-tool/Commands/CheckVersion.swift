import ArgumentParser
import Foundation

struct CheckVersionCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "check-version",
        abstract: "Check resource versions"
    )

    @OptionGroup var db: VPSDbArguments

    @Option
    var cache: URL

    mutating func run() async throws {
        let db = try db.database()

        let client = HTTPClient(cache: cache, throttle: .seconds(3))
        //        let list = db.tables.all.filter { $0.site != .other }.prefix(10)
        let list = db.games["52p0QnVVAH"]!.tables

        for t in list {
            if let url = t.url {
                print(url)
                _ = try await client.get(url)
            }
        }
    }
}
