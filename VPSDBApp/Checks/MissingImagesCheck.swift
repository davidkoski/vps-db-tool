import Foundation
import SwiftUI
import VPSDB

// MARK: - Missing fields

/// Resources with no authors, version or created date -- the fix scans the
/// resource's page(s) and fills in the missing fields.
struct MissingImagesCheck: ResourceCheck {
    var id: String { "missingImages" }
    var name: String { "No image or 404 image" }
    var kinds: Set<GameResourceKind> { [.table, .b2s] }
    var version = 1

    func problems(_ resource: any GameResource, game: Game, context: CheckContext) -> [String] {
        guard !resource.urls.isEmpty else { return [] }
        guard let resource = resource as? HasScreenshot else { return [] }

        if let imageUrl = resource.imgUrl {
            if imageUrl.host() == "virtualpinballspreadsheet.github.io" {
                let path = context.settings.imagesURL.appending(
                    component: imageUrl.lastPathComponent)
                if !((try? path.checkResourceIsReachable()) ?? false) {
                    return ["Image Missing"]
                } else {
                    return []
                }
            } else {
                return ["External Image"]
            }
        } else {
            return ["No Image"]
        }
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
                return .init(resource: resource, detail: detail, changes: [])
            } catch {
                failures.append(
                    "\(url.host() ?? url.absoluteString): \(error.localizedDescription)")
            }
        }
        throw CheckError.noFix(failures.isEmpty ? "No URLs" : failures.joined(separator: "; "))
    }
}
