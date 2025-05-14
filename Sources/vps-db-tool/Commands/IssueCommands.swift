import ArgumentParser
import Foundation

struct IssueCommands: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "issue",
        abstract: "issue related commands",
        subcommands: [
            IgnoreCommand.self
        ]
    )
}

private struct IgnoreCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "ignore",
        abstract: "ignore a url"
    )

    @OptionGroup var issues: IssuesArguments
    @Option var kind: GameResourceKind = .table

    @Option(parsing: .upToNextOption) var url: [URL]
    @Option var comment = "Obsolete"

    mutating func run() async throws {
        var issues = try issues.database()

        for url in url {
            let detail = DetailResult(url: url)
            let issue = URLIssue.entryNotFound(detail)
            issues.report(kind: kind, url: url, issue: issue, comment: comment)
        }

        try self.issues.save(db: issues)
    }
}
