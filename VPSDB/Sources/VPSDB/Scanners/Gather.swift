import Foundation
import Logging

private let log = Logger(label: "Gather")

/// Gather list results.
///
/// - Parameters:
///   - client: http client
///   - maxAge: max age of the http disk cache
///   - scanCache: optional ScanCache
///   - requests: urls/pages to fetch
///   - suppress: suppress policy
///   - follow: follow detail url policy
/// - Returns: stream of list level detail results
public func gather(
    client: HTTPClient,
    maxAge: Duration,
    scanCache: ScanCache?,
    requests: [ListScanRequest],
    suppress: [URL: SuppressionReason],
    follow: @escaping @Sendable (DetailResult) -> Bool
) -> AsyncStream<DetailResult> {

    return AsyncStream { continuation in
        let producer = Task {
            var maxPage = Int.max
            for request in requests {
                log.info("SCAN ITEM \(request.site) \(request.kind) \(request.url)")

                if request.page > maxPage {
                    continue
                }

                try Task.checkCancellation()

                var scanResult: ListResult

                if let cachedList = await scanCache?.get(request: request),
                    !cachedList.isExpired(maxAge: maxAge),
                    let result = await cachedList.reconstitute(scanCache: scanCache)
                {
                    scanResult = result

                } else {
                    do {
                        let content = try await client.getString(request.url, maxAge: maxAge)
                        scanResult = try await request.scan(content: content)

                        await scanCache?.cache(request: request, item: scanResult)

                    } catch {
                        log.error(
                            "Failed to gather from \(request.site) \(request.kind) \(request.url): \(type(of: error)) \(String(reflecting: error))"
                        )
                        continue
                    }
                }

                // update maxPage so we can stop early
                if let pages = scanResult.pages, maxPage == .max {
                    maxPage = pages
                }

                // filter out anything that is being suppressed
                scanResult.list = scanResult.list
                    .filter {
                        if let reason = suppress[$0.url] {
                            return !reason.shouldSuppress()
                        }
                        return true
                    }

                log.info(
                    "SCAN \(request.site) \(request.kind) - PROCESS LIST \(scanResult.list.count)")

                for item in scanResult.list {
                    log.info("PROCESS \(request.site) \(request.kind): \(item.name) \(item.url)")

                    // if the detailKind is .detail it is already resolved
                    if item.detailKind == .list && follow(item) {
                        do {
                            let detailRequest = item.detailRequest
                            let content = try await client.getString(item.url, maxAge: maxAge)
                            if let detail = try await detailRequest.scan(content: content) {
                                await scanCache?.cache(request: detailRequest, item: detail)
                                continuation.yield(detail)
                            }
                        } catch {
                            log.error(
                                "Error fetching \(item.url): \(type(of: error)) \(String(reflecting: error))"
                            )
                            continuation.yield(item)
                        }
                    } else {
                        continuation.yield(item)
                    }
                }
            }

            continuation.finish()
        }

        continuation.onTermination = { _ in
            producer.cancel()
        }
    }
}
