import Foundation

/// ``DetailScanner`` for YouTube watch pages.
///
/// The page metadata looks like:
///
/// ```html
/// <meta property="og:title" content="...">
/// <span itemprop="author" itemscope itemtype="http://schema.org/Person">
///   <link itemprop="name" content="Channel Name">
/// </span>
/// <meta itemprop="datePublished" content="2021-03-04T10:00:13-08:00">
/// ```
public struct YouTubeScanner: DetailScanner {

    public init() {
    }

    public func scanDetail(
        request: DetailScanRequest, content: String
    ) throws -> DetailResult? {
        let url = request.url
        let kind = request.kind

        let page = try PageMetadata(url: url, content: content)

        let author =
            page.attr("span[itemprop=author] link[itemprop=name]", "content")
            ?? page.meta("meta[name=author]")

        let date = page.meta("meta[itemprop=datePublished]", "meta[itemprop=uploadDate]")
            .flatMap(parseDate)

        // the thumbnail is predictable from the id; og:image is usually the same image
        // at a different size
        var images = [URL]()
        if let id = youtubeVideoId(url),
            let thumbnail = URL(string: "https://i.ytimg.com/vi/\(id)/hqdefault.jpg")
        {
            images.append(thumbnail)
        }
        if let image = page.image, !images.contains(image) {
            images.append(image)
        }

        return DetailResult(
            url: url, kind: kind, name: page.title, author: author, date: date,
            text: page.description, images: images)
    }
}

extension YouTubeScanner: ScanSources {

    /// Playlists to scan, per kind.
    public static let playlists: [GameResourceKind: [String]] = [
        // "https://www.youtube.com/playlist?list=PLxxxxxxxxxxxxxxxx"
        .tutorial: [
            // Digital Victory
            "https://www.youtube.com/playlist?list=PLNBBYj2fs2QUkoHqsYj6YjsmCXhuW7Z5M",
            // Chuckwurt
            "https://www.youtube.com/playlist?list=PLkfeetnClaXlQXi7rCPRGlfln6Wm3GDr3",
            // Papa Pinball
            "https://www.youtube.com/playlist?list=PL-WQLGFMr97CQpOQDEvRqAiSqcvSuK11h",
            // AKM's Pinball Videos
            "https://www.youtube.com/playlist?list=PLcGmf6V32esB21BPVOBNiYCIp5q7mglPu",
            // Majestic Pinball
            "https://www.youtube.com/playlist?list=PLzUvyfLN2ZSll4s79bXVubyZ8O7_vZnDs",
            // Quick Ass Pinball
            "https://www.youtube.com/playlist?list=PLkySklV5pqq87ZF28ZR8KNCukSR4CTtjv",
            // Alpha Bravo Pinball
            "https://www.youtube.com/playlist?list=PLwislUQBbcM-Z9CDTxnQBojJHdvNzm1jn",
            // Rumbaabaa PinVids
            "https://www.youtube.com/playlist?list=PLBoCO-wRyr4M",
            // Pinball Pursuit
            "https://www.youtube.com/playlist?list=PL_A-N3XqJGU3oR0SCkJjeJELWhEHieu6H",
            // District 82 Pinball
            "https://www.youtube.com/playlist?list=PLnpouQ1vT6iQlnTGfCcOj_50Ddy6Ras7d",
            // BordDog
            "https://www.youtube.com/playlist?list=PLD_-eCv4JugjePD8z1P1QWRGuvm-Z4IIf",
        ]
    ]

    public func sources(kind: GameResourceKind) -> [URL] {
        (Self.playlists[kind] ?? []).compactMap { URL(string: $0) }
    }

    public func update(kind: GameResourceKind, url: URL, page: Int) -> URL? {
        page > 1 ? nil : url
    }
}

extension YouTubeScanner: ListScanner {

    /// Scan a playlist page.
    ///
    /// The videos are in the `ytInitialData` json, assigned in a `<script>`:
    ///
    /// ```js
    /// var ytInitialData = {"contents": {"twoColumnBrowseResultsRenderer": ...}};
    /// ```
    ///
    /// Note: this info is from gemini and then the rest of the parsing is
    /// by looking at the JSON.  This could potentially change over time.
    public func scanList(request: ListScanRequest, content: String) throws -> ListResult {
        let url = request.url
        let kind = request.kind

        guard let json = Self.initialData(content) else {
            return ListResult(pages: 1, list: [])
        }

        var items = [DetailResult]()
        var seen = Set<String>()

        Self.visit(json, key: "lockupViewModel") { dict in

            guard
                let title = Self.value(
                    dict, ["metadata", "lockupMetadataViewModel", "title", "content"]
                )
            else { return }

            guard
                let id = Self.value(
                    dict, ["contentId"]
                )
            else { return }

            guard
                let rows = Self.array(
                    dict,
                    [
                        "metadata", "lockupMetadataViewModel", "metadata",
                        "contentMetadataViewModel", "metadataRows",
                    ]
                )
            else { return }

            guard rows.count > 0 else { return }
            let row = rows[0]

            guard
                let parts = Self.array(
                    row, ["metadataParts"]
                )
            else { return }

            guard parts.count > 0 else { return }
            let part = parts[0]

            guard
                let author = Self.value(
                    part, ["text", "content"]
                )
            else { return }

            seen.insert(id)

            let videoURL = URL(string: "https://www.youtube.com/watch?v=\(id)")!

            items.append(
                .init(
                    url: videoURL, kind: kind,
                    name: title, author: author
                ))
        }

        return ListResult(pages: 1, list: items)
    }

    /// The `ytInitialData` json object from the page.
    static func initialData(_ content: String) -> [String: Any]? {
        let markers = ["var ytInitialData = ", "window[\"ytInitialData\"] = ", "ytInitialData = "]
        guard let marker = markers.lazy.compactMap({ content.range(of: $0) }).first else {
            return nil
        }

        // from the assignment to the end of its <script> -- the json is the
        // first "{" through the last "}" before that
        let rest = content[marker.upperBound...]
        let end = rest.range(of: "</script>")?.lowerBound ?? rest.endIndex
        let script = rest[..<end]
        guard let open = script.firstIndex(of: "{"), let close = script.lastIndex(of: "}") else {
            return nil
        }

        let data = Data(script[open ... close].utf8)
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    /// Call `body` with every object stored under `key`, anywhere in `json`.
    static func visit(_ json: Any, key: String, _ body: ([String: Any]) -> Void) {
        if let object = json as? [String: Any] {
            for (k, value) in object {
                if k == key, let match = value as? [String: Any] {
                    body(match)
                } else {
                    visit(value, key: key, body)
                }
            }
        } else if let array = json as? [Any] {
            for value in array {
                visit(value, key: key, body)
            }
        }
    }

    static func value(_ json: Any, _ keys: [String]) -> String? {
        var root = json
        for key in keys {
            if let dict = root as? [String: Any] {
                if let new = dict[key] {
                    root = new
                } else {
                    return nil
                }
            }
        }

        if let value = root as? String {
            return value
        } else {
            return nil
        }
    }

    static func array(_ json: Any, _ keys: [String]) -> [Any]? {
        var root = json
        for key in keys {
            if let dict = root as? [String: Any] {
                if let new = dict[key] {
                    root = new
                } else {
                    return nil
                }
            }
        }

        if let value = root as? [Any] {
            return value
        } else {
            return nil
        }
    }
}
