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

    static func canonical(_ url: URL) -> URL {
        Site(url).canonicalize(url)
    }

    /// convert a URL into a canonical form -- remove any parts that can vary without consequence
    func canonicalize(_ url: URL) -> URL {
        var url = url
        if url.scheme == "http" {
            url = URL(
                string: url.description.replacingOccurrences(of: "http://", with: "https://"))!
        }

        switch self {
        case .vpuniverse:
            // any url of the form
            // https://vpuniverse.com/files/file/24527-any/
            //
            // will redirect to the current one, e.g.:
            // https://vpuniverse.com/files/file/24527-rush-le-tribute-v104/

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
        case .vpforums:
            // https://www.vpforums.org/index.php?s=1626316605b94c1502262391eba17e6a&app=downloads&showfile=17011
            let string = url.description
                .replacing(/s=[0-9a-f]+&/, with: "")
                .replacing(/#$/, with: "")
            return URL(string: string)!

        case .pinballnirvana: return url
        case .other: return url
        }
    }

    /// convert a URL into its ideal form for use in the database -- remove any extra parts
    func normalize(_ url: URL) -> URL {
        var url = url
        if url.scheme == "http" {
            url = URL(
                string: url.description.replacingOccurrences(of: "http://", with: "https://"))!
        }

        switch self {
        case .vpuniverse:
            // strip query params, e.g. tab and comment selections
            if url.query() != nil,
                var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            {
                components.queryItems = nil
                if let new = components.url {
                    url = new
                }
            }

            // remove the /formums links
            if url.path().hasPrefix("/forums/files/") {
                url = URL(
                    string: "https://vpuniverse.com/"
                        + url.pathComponents.dropFirst(2).joined(separator: "/") + "/")!
            }

            return url

        case .vpforums:
            // https://www.vpforums.org/index.php?s=1626316605b94c1502262391eba17e6a&app=downloads&showfile=17011
            let string = url.description
                .replacing(/s=[0-9a-f]+&/, with: "")
                .replacing(/#$/, with: "")
            return URL(string: string)!

        case .pinballnirvana: return url
        case .other: return url
        }
    }
}
