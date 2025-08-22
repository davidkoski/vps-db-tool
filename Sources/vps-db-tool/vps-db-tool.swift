import ArgumentParser
import AsyncHTTPClient
import Foundation
import NIOFoundationCompat
import VPSDB

@main
struct VPSDbTool: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Command line tool to assist withvps-db",
        subcommands: [
            DownloadCommand.self, CheckCommands.self, ExploreCommand.self,
            IPDBCommands.self, ScanCommands.self, EditCommands.self,
            IssueCommands.self, ReportCommand.self, TutorialCommands.self,
        ]
    )
}

struct VPSDbArguments: ParsableArguments, Sendable {

    @Option(name: .customLong("db"), help: "Path to vpsdb.json")
    var path: URL = URL(fileURLWithPath: "../vps-db/db/vpsdb.json")

    private var db: Database?

    enum HTTPError: Error {
        case httpError(Int, String)
    }

    mutating func database() async throws -> Database {
        if let db {
            return db
        }

        if path.isFileURL {
            let db = try JSONDecoder().decode(Database.self, from: Data(contentsOf: path))
            self.db = db
            return db
        } else {
            let httpRequest = HTTPClientRequest(url: path.description)
            let response = try await HTTPClient.shared.execute(httpRequest, timeout: .seconds(30))
            guard response.status == .ok else {
                throw HTTPError.httpError(Int(response.status.code), response.status.reasonPhrase)
            }

            let data = try await response.body.collect(upTo: 20 * 1024 * 1024)
            return try data.getJSONDecodable(
                Database.self, decoder: JSONDecoder(), at: data.readerIndex,
                length: data.readableBytes)!
        }
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
