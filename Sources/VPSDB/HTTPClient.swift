import AsyncHTTPClient
import Foundation
import NIOHTTP1

enum HTTPError: Error {
    case unableToReadBody
    case unableToDecodeString(URL)
    case response(URL, HTTPResponseStatus, String)
}

public class HTTPClient {

    let client: AsyncHTTPClient.HTTPClient

    let userAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.4 Safari/605.1.15"

    let cache: URL?

    let throttle: Duration?
    var lastRequest: ContinuousClock.Instant?

    public init(cache: URL? = nil, throttle: Duration? = nil) {
        self.client = .init()
        self.cache = cache
        self.throttle = throttle
        self.lastRequest = nil
    }

    deinit {
        try! client.syncShutdown()
    }

    private func pathify(_ url: URL) -> String {
        let s = url.description
            .replacingOccurrences(of: "://", with: ".")
            .replacingOccurrences(of: "/", with: ".")

        return s.hasSuffix(".html") ? s : s + ".html"
    }

    public func get(_ url: URL, bypassCache: Bool = false) async throws -> Data {
        let cache = cache?.appending(path: pathify(url))
        if !bypassCache, let cache {
            if let data = try? Data(contentsOf: cache) {
                return data
            }
        }

        if let throttle {
            if let lastRequest {
                let now = ContinuousClock.Instant.now
                let diff = now - lastRequest
                if diff < throttle {
                    try await Task.sleep(for: throttle - diff)
                }
            }
        }

        var request = HTTPClientRequest(url: url.description)
        request.headers = ["User-Agent": userAgent]

        let response = try await client.execute(request, timeout: .seconds(10))

        if response.status != .ok {
            throw HTTPError.response(url, response.status, response.status.reasonPhrase)
        }

        let data = try await response.body.collect(upTo: 100 * 1024 * 1024)

        lastRequest = ContinuousClock.Instant.now

        if let data = data.getData(at: data.readerIndex, length: data.readableBytes) {
            if let cache {
                try? data.write(to: cache, options: .atomic)
            }
            return data
        } else {
            throw HTTPError.unableToReadBody
        }
    }

    public func getString(_ url: URL, bypassCache: Bool = false) async throws -> String {
        let data = try await get(url, bypassCache: bypassCache)
        if let s = String(data: data, encoding: .utf8) {
            return s
        }
        return data.withUnsafeBytes {
            $0.withMemoryRebound(to: UInt8.self) { buffer in
                String(cString: buffer.baseAddress!)
            }
        }
    }
}
