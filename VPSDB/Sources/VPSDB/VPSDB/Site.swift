import Foundation

public enum Site: String, Hashable, Sendable, Codable {
    case vpu = "VPU"
    case vpf = "VPF"
    case pinballnirvana = "Nirvana"
    case pinballPrimer = "Primer"
    case youtube = "YouTube"
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
        case "pinballprimer.github.io": self = .pinballPrimer
        case "www.youtube.com", "youtube.com", "m.youtube.com", "music.youtube.com", "youtu.be":
            self = .youtube
        default: self = .other
        }
    }

    public static let scanSites = [Site.vpu, .vpf, .pinballnirvana, .pinballPrimer, .youtube]

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

        case .youtube: return youtubeWatchURL(url) ?? url
        case .pinballnirvana:
            // https://pinballnirvana.com/forums/resources/off-road-racers-original.8611/
            if url.path().hasPrefix("/forums/resources/") {
                let last = url.lastPathComponent
                let pieces = last.split(separator: ".")
                let new =
                    if pieces.count == 2 {
                        "any.\(pieces[1])"
                    } else {
                        last
                    }
                return url.deletingLastPathComponent().appending(
                    component: new, directoryHint: .isDirectory)
            } else {
                return url
            }

        case .pinballPrimer: return url
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

        case .youtube: return youtubeWatchURL(url) ?? url
        case .pinballnirvana: return url
        case .pinballPrimer: return url
        case .other: return url
        }
    }
}

/// Extract the video id from the various forms of YouTube URL:
///
/// - `https://www.youtube.com/watch?v=ID&list=...`
/// - `https://youtu.be/ID?t=10`
/// - `https://www.youtube.com/shorts/ID`, `/embed/ID`, `/live/ID`, `/v/ID`
public func youtubeVideoId(_ url: URL) -> String? {
    guard Site(url) == .youtube else { return nil }

    let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    if let v = components?.queryItems?.first(where: { $0.name == "v" })?.value, !v.isEmpty {
        return v
    }

    let path = url.pathComponents.filter { $0 != "/" }
    if url.host() == "youtu.be" {
        return path.first
    }
    if path.count >= 2, ["shorts", "embed", "live", "v"].contains(path[0]) {
        return path[1]
    }
    return nil
}

/// Canonical `https://www.youtube.com/watch?v=ID` form of a YouTube URL.
public func youtubeWatchURL(_ url: URL) -> URL? {
    guard let id = youtubeVideoId(url) else { return nil }
    return URL(string: "https://www.youtube.com/watch?v=\(id)")
}
