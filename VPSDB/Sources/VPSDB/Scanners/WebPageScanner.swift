import Foundation
import SwiftSoup

/// ``DetailScanner`` for arbitrary web pages (blogs, rule sheets, etc.).
///
/// Uses the standard metadata most pages provide: OpenGraph (`og:*`),
/// schema.org microdata (`itemprop`), and plain `<meta>` / `<title>` tags.
public struct WebPageScanner: DetailScanner {

    public init() {
    }

    public func scanDetail(
        request: DetailScanRequest, content: String
    ) throws -> DetailResult? {
        let url = request.url
        let kind = request.kind

        let page = try PageMetadata(url: url, content: content)

        let author =
            page.meta(
                "meta[name=author]", "meta[property=article:author]", "meta[name=twitter:creator]",
                "meta[property=og:site_name]")
            ?? url.host()

        let date = page.meta(
            "meta[itemprop=datePublished]", "meta[property=article:published_time]",
            "meta[property=article:modified_time]", "meta[itemprop=dateModified]"
        ).flatMap(parseDate)

        return DetailResult(
            url: url, kind: kind, name: page.title, author: author, date: date,
            text: page.description, images: page.image.map { [$0] } ?? [])
    }
}

/// Common page metadata lookups shared by the generic scanners.
struct PageMetadata {
    let url: URL
    let html: Document

    init(url: URL, content: String) throws {
        self.url = url
        self.html = try SwiftSoup.parse(content, url.absoluteString)
    }

    /// The `content` attribute of the first matching selector that has one.
    func meta(_ selectors: String...) -> String? {
        for selector in selectors {
            if let value = attr(selector, "content") {
                return value
            }
        }
        return nil
    }

    /// The (non-empty) attribute of the first element matching `selector`.
    func attr(_ selector: String, _ name: String) -> String? {
        (try? html.select(selector).first()?.attr(name))?.nonEmpty
    }

    var title: String? {
        meta("meta[property=og:title]", "meta[name=title]", "meta[name=twitter:title]")
            ?? (try? html.title())?.nonEmpty
    }

    var description: String? {
        meta(
            "meta[property=og:description]", "meta[name=description]",
            "meta[name=twitter:description]")
    }

    var image: URL? {
        meta("meta[property=og:image]", "meta[name=twitter:image]")
            .flatMap { URL(string: $0, relativeTo: url)?.absoluteURL }
    }
}

/// Parse the various ISO 8601 forms seen in page metadata:
/// `2021-03-04T10:00:13-08:00`, `2021-03-04T18:00:13.123Z`, `2021-03-04`.
func parseDate(_ string: String) -> Date? {
    let full = ISO8601DateFormatter()
    if let date = full.date(from: string) {
        return date
    }

    let fractional = ISO8601DateFormatter()
    fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = fractional.date(from: string) {
        return date
    }

    let dateOnly = ISO8601DateFormatter()
    dateOnly.formatOptions = [.withFullDate]
    return dateOnly.date(from: String(string.prefix(10)))
}

extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
