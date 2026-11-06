import Foundation
import SwiftUI
import VPSDB

// MARK: - Missing fields

/// Resources with no authors, version or created date -- the fix scans the
/// resource's page(s) and fills in the missing fields.
struct MissingFieldsCheck: ResourceCheck {
    var id: String { "missingFields" }
    var name: String { "Missing Author, Version or Date" }
    var kinds: Set<GameResourceKind> { [.b2s] }
    var version = 1

    func problems(_ resource: any GameResource, game: Game, context: CheckContext) -> [String] {
        let common = resource.gameResource
        var problems = [String]()
        if common.authors.isEmpty {
            problems.append("No author")
        }
        if hasVersion(resource.kind), (common.version ?? "").isEmpty {
            problems.append("No version")
        }
        if common.createdAt == .distantPast {
            problems.append("No date")
        }
        return problems
    }

    func fix(_ item: CheckItem, context: CheckContext) async throws -> FixProposal? {
        guard let resource = context.resource(for: item) else { return nil }
        var failures = [String]()
        for url in resource.urls {
            let request = DetailScanRequest(url, resource.kind)
            guard request.site.scanner != nil else {
                failures.append("\(url.host() ?? url.absoluteString): unsupported site")
                continue
            }
            do {
                let detail = try await request.fetch(client: context.client, scanCache: scanCache)
                let proposal = propose(resource, from: detail, db: context.db)
                if !proposal.changes.isEmpty {
                    return proposal
                }
                failures.append("\(url.host() ?? url.absoluteString): nothing new")
            } catch {
                failures.append("\(url.host() ?? url.absoluteString): \(error.localizedDescription)")
            }
        }
        throw CheckError.noFix(failures.isEmpty ? "No URLs" : failures.joined(separator: "; "))
    }

    /// Fill the missing fields of `resource` from `detail`.
    private func propose<R: GameResource>(_ resource: R, from detail: DetailResult, db: Database)
        -> FixProposal
    {
        var new = resource
        var changes = [ProposedChange]()

        if new.gameResource.authors.isEmpty, detail.author != "unknown", !detail.author.isEmpty {
            let author = db.matchAuthor(name: detail.author)
            new.gameResource.authors = [author]
            changes.append(.init(field: .authors, old: "—", new: author.name))
        }

        if hasVersion(resource.kind), (new.gameResource.version ?? "").isEmpty {
            let version = cleanVersion(detail.version)
            if !version.isEmpty {
                new.gameResource.version = version
                changes.append(.init(field: .version, old: "—", new: version))
            }
        }

        // only a real date -- `resolvedDate` is "now" for undated pages
        if new.gameResource.createdAt == .distantPast, case .date(let date) = detail.date {
            new.gameResource.createdAt = date
            changes.append(
                .init(
                    field: .createdAt, old: "—",
                    new: date.formatted(date: .abbreviated, time: .omitted)))
        }

        return FixProposal(resource: new, detail: detail, changes: changes)
    }

    private func hasVersion(_ kind: GameResourceKind) -> Bool {
        editableType(for: kind)?.hasVersion ?? true
    }
}
