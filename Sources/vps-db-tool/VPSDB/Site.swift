import Foundation

enum Site: Sendable {
    case vpuniverse
    case vpforums
    case pinballnirvana
    case other

    init?(_ url: URL?) {
        if let url {
            switch url.host() {
            case "vpuniverse.com": self = .vpuniverse
            case "www.vpforums.org": self = .vpforums
            case "pinballnirvana.com": self = .pinballnirvana
            default: self = .other
            }
        } else {
            return nil
        }
    }
}
