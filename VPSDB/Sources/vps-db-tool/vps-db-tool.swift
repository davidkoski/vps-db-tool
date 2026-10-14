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
            ReportCommand.self, TutorialCommands.self,
            ImportCommands.self,
        ]
    )
}

struct VPSDbArguments: ParsableArguments, Sendable {

    @Option(name: .customLong("db"), help: "Path to vpsdb.json")
    var path: URL = URL(fileURLWithPath: "../vps-db/db/vpsdb.json")

    private var db: Database?

    @Option(name: .customLong("document"), help: "Path to VPSDB.vpsdbdoc")
    var document: URL?

    public func suppressedURLs() throws -> [URL: SuppressionReason] {
        if let document {
            let data = try Data(contentsOf: document)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let document = try decoder.decode(Document.self, from: data)
            return Dictionary(
                uniqueKeysWithValues: document.suppressedURLs.map {
                    (URL(string: $0.key)!, $0.value)
                })
        } else {
            return [:]
        }
    }

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
            let db = try data.getJSONDecodable(
                Database.self, decoder: JSONDecoder(), at: data.readerIndex,
                length: data.readableBytes)!
            self.db = db
            return db
        }
    }
}

struct Document: Codable {
    var suppressedURLs = [String: SuppressionReason]()
}
