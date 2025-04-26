import Foundation

struct SingleTable: Sendable {
    let name: String?
    let author: String?
    let version: String?
    let ipdb: URL?
    let features: Set<Feature>
    let b2s: URL?
    let mediaPack: URL?
}
