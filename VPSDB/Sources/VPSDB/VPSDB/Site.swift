import Foundation

public enum Site: String, Sendable {
    case vpu = "VPU"
    case vpf = "VPF"
    case pinballnirvana = "Nirvana"
    case other = "Other"

    public init?(_ url: URL?) {
        if let url {
            self.init(url)
        } else {
            return nil
        }
    }

    public init(_ url: URL) {
        switch url.host() {
        case "vpuniverse.com": self = .vpu
        case "www.vpforums.org": self = .vpf
        case "pinballnirvana.com": self = .pinballnirvana
        default: self = .other
        }
    }

    public static func canonical(_ url: URL) -> URL {
        Site(url).canonicalize(url)
    }

    /// convert a URL into a canonical form -- remove any parts that can vary without consequence
    public func canonicalize(_ url: URL) -> URL {
        var url = url
        if url.scheme == "http" {
            url = URL(
                string: url.description.replacingOccurrences(of: "http://", with: "https://"))!
        }

        switch self {
        case .vpu:
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
        case .vpf:
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
    public func normalize(_ url: URL) -> URL {
        var url = url
        if url.scheme == "http" {
            url = URL(
                string: url.description.replacingOccurrences(of: "http://", with: "https://"))!
        }

        switch self {
        case .vpu:
            // strip query params, e.g. tab and comment selections
            if url.query() != nil,
                var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            {
                components.queryItems = nil
                if let new = components.url {
                    url = new
                }
            }

            if !url.path().hasSuffix("/") {
                url = URL(string: url.description + "/")!
            }

            // remove the /formums links
            if url.path().hasPrefix("/forums/files/") {
                url = URL(
                    string: "https://vpuniverse.com/"
                        + url.pathComponents.dropFirst(2).joined(separator: "/") + "/")!
            }

            return url

        case .vpf:
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
