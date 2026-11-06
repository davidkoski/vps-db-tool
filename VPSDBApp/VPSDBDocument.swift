import Foundation
import Observation
import SwiftUI
import UniformTypeIdentifiers
import VPSDB

extension UTType {
    /// Exported in Info.plist (`UTExportedTypeDeclarations`).
    nonisolated static let vpsdbDocument = UTType(
        exportedAs: "com.koski.vpsdb.document", conformingTo: .json)
}

/// The persisted content of a document.
nonisolated struct VPSDBModel: Codable, Sendable, Equatable {

    /// Updates that shouldn't be offered, keyed by the canonical url
    /// (``DetailResult/url``).
    var suppressedURLs = [URL: SuppressionReason]()

    /// Check results that shouldn't be shown -- see ``CheckSuppression``.
    var suppressedChecks = Set<CheckSuppression>()

    init() {
    }

    // stored keyed by the url string -- a [URL: ...] dictionary encodes as a
    // flat [key, value, key, value, ...] array in JSON

    private enum CodingKeys: String, CodingKey {
        case suppressedURLs
        case suppressedChecks
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let byString =
            try container.decodeIfPresent(
                [String: SuppressionReason].self, forKey: .suppressedURLs) ?? [:]
        suppressedURLs = Dictionary(
            uniqueKeysWithValues: byString.compactMap { key, value in
                URL(string: key).map { ($0, value) }
            })
        // absent in older documents
        suppressedChecks =
            try container.decodeIfPresent(Set<CheckSuppression>.self, forKey: .suppressedChecks)
            ?? []
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let byString = Dictionary(
            uniqueKeysWithValues: suppressedURLs.map { ($0.key.absoluteString, $0.value) })
        try container.encode(byString, forKey: .suppressedURLs)
        // sorted -- a stable file (sets encode in arbitrary order)
        try container.encode(suppressedChecks.sorted(), forKey: .suppressedChecks)
    }
}

/// A check result (a resource flagged by a check) that shouldn't be shown.
///
/// Recorded with the check's version: bumping ``ResourceCheck/version``
/// (e.g. after changing what it looks for) shows suppressed items again.
nonisolated struct CheckSuppression: Codable, Sendable, Hashable, Comparable {
    let kind: GameResourceKind
    let resourceId: String
    let checkId: String
    let checkVersion: Int

    static func < (lhs: CheckSuppression, rhs: CheckSuppression) -> Bool {
        (lhs.checkId, lhs.checkVersion, lhs.kind.rawValue, lhs.resourceId)
            < (rhs.checkId, rhs.checkVersion, rhs.kind.rawValue, rhs.resourceId)
    }
}

/// Document using the macOS 27 `Document` protocol (replaces `FileDocument` / `ReferenceFileDocument`).
///
/// The framework reads on a background executor via ``Reader``, then calls ``apply(snapshot:previous:)``
/// on the main actor.  For saving it calls ``snapshot(contentType:)`` on the main actor and hands the
/// result to ``Writer`` off the main actor.
@Observable
final class VPSDBDocument: Document {

    var model = VPSDBModel()

    nonisolated static var readableContentTypes: [UTType] { [.vpsdbDocument] }

    // MARK: - Reading

    nonisolated func reader(configuration: sending ReadConfiguration)
        -> sending FileWrapperDocumentReader<VPSDBModel>
    {
        FileWrapperDocumentReader(configuration) { wrapper in
            guard let data = wrapper.regularFileContents, !data.isEmpty else {
                return VPSDBModel()
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(VPSDBModel.self, from: data)
        }
    }

    func apply(snapshot: sending VPSDBModel, previous: sending VPSDBModel?) async throws {
        model = snapshot
    }

    // MARK: - Writing

    nonisolated func writer(configuration: sending WriteConfiguration)
        -> sending FileWrapperDocumentWriter<VPSDBModel>
    {
        FileWrapperDocumentWriter(configuration) { snapshot, _ in
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            encoder.dateEncodingStrategy = .iso8601
            return FileWrapper(regularFileWithContents: try encoder.encode(snapshot))
        }
    }

    func snapshot(contentType: UTType) async throws -> VPSDBModel {
        model
    }
}
