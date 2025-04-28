import Foundation

enum Site: Sendable {
    case vpuniverse
    case vpforums
    case pinballnirvana
    case other

    init?(_ url: URL?) {
        if let url {
            self.init(url)
        } else {
            return nil
        }
    }

    init(_ url: URL) {
        switch url.host() {
        case "vpuniverse.com": self = .vpuniverse
        case "www.vpforums.org": self = .vpforums
        case "pinballnirvana.com": self = .pinballnirvana
        default: self = .other
        }
    }

    func canonicalize(_ url: URL) -> URL {
        switch self {
        case .vpuniverse:
            // any url of the form
            // https://vpuniverse.com/files/file/24527-any/
            //
            // will redirect to the current one, e.g.:
            // https://vpuniverse.com/files/file/24527-rush-le-tribute-v104/

            var url = url
            if url.path().hasPrefix("/forums/files/") {
                url = URL(
                    string: "https://vpuniverse.com/"
                        + url.pathComponents.dropFirst(2).joined(separator: "/") + "/")!
            }

            if url.path().hasPrefix("/files/file/") {
                let last = url.lastPathComponent
                let new = last.prefix { $0.isNumber } + "-any"
                return url.deletingLastPathComponent().appending(
                    component: new, directoryHint: .isDirectory)
            } else {
                return url
            }
        case .vpforums: return url
        case .pinballnirvana: return url
        case .other: return url
        }
    }
}
