import Foundation
import Testing
import VPSDB

struct WebPageScannerTests {

    @Test(arguments: [
        ("https://www.youtube.com/watch?v=afIOXq040dM", "afIOXq040dM"),
        (
            "https://www.youtube.com/watch?v=afIOXq040dM&list=PLcGmf6V32esB21BPVOBNiYCIp5q7mglPu&index=19",
            "afIOXq040dM"
        ),
        ("https://youtu.be/afIOXq040dM?t=10", "afIOXq040dM"),
        ("https://www.youtube.com/shorts/afIOXq040dM", "afIOXq040dM"),
        ("https://www.youtube.com/embed/afIOXq040dM", "afIOXq040dM"),
        ("https://m.youtube.com/watch?v=afIOXq040dM", "afIOXq040dM"),
    ])
    func testYouTubeId(url: String, id: String) {
        #expect(youtubeVideoId(URL(string: url)!) == id)
    }

    @Test func testYouTubeIdNotYouTube() {
        #expect(youtubeVideoId(URL(string: "https://vpuniverse.com/files/file/1234-x/")!) == nil)
        #expect(youtubeVideoId(URL(string: "https://www.youtube.com/@channel")!) == nil)
    }

    @Test func testYouTubeCanonical() {
        let url = URL(
            string:
                "https://www.youtube.com/watch?v=afIOXq040dM&list=PLcGmf6V32esB21BPVOBNiYCIp5q7mglPu&index=19"
        )!
        #expect(Site(url) == .youtube)
        #expect(
            Site.canonical(url).absoluteString == "https://www.youtube.com/watch?v=afIOXq040dM")
    }

    @Test func testYouTubePage() throws {
        let url = URL(string: "https://www.youtube.com/watch?v=afIOXq040dM&list=PL123")!
        let html = """
            <html><head>
            <title>Sharkey's Shootout gameplay - YouTube</title>
            <meta name="title" content="Sharkey's Shootout pinball machine gameplay">
            <meta property="og:title" content="Sharkey's Shootout pinball machine gameplay">
            <meta property="og:image" content="https://i.ytimg.com/vi/afIOXq040dM/maxresdefault.jpg">
            <meta property="og:description" content="A tutorial">
            </head><body>
            <span itemprop="author" itemscope itemtype="http://schema.org/Person">
              <link itemprop="url" href="http://www.youtube.com/@akm">
              <link itemprop="name" content="AKM's Pinball Videos">
            </span>
            <meta itemprop="datePublished" content="2021-03-04T10:00:13-08:00">
            </body></html>
            """

        let detail = try #require(
            try YouTubeScanner().scanDetail(url: url, content: html, kind: .tutorial))

        #expect(detail.site == .youtube)
        #expect(detail.url.absoluteString == "https://www.youtube.com/watch?v=afIOXq040dM")
        #expect(detail.name == "Sharkey's Shootout pinball machine gameplay")
        #expect(detail.author == "AKM's Pinball Videos")
        #expect(detail.date.timeIntervalSince1970 == 1_614_880_813)
        #expect(detail.text == "A tutorial")
        #expect(detail.images.count == 2)
        #expect(
            detail.images.first?.absoluteString
                == "https://i.ytimg.com/vi/afIOXq040dM/hqdefault.jpg")
    }

    @Test func testGenericPage() throws {
        let url = URL(string: "https://pinballprimer.github.io/alienpoker_G4yen.html")!
        let html = """
            <html><head>
            <title>Alien Poker - Pinball Primer</title>
            <meta property="og:site_name" content="Pinball Primer">
            <meta property="article:published_time" content="2020-01-02">
            </head><body></body></html>
            """

        let detail = try #require(
            try WebPageScanner().scanDetail(url: url, content: html, kind: .tutorial))

        #expect(detail.site == .pinballPrimer)
        #expect(detail.name == "Alien Poker - Pinball Primer")
        #expect(detail.author == "Pinball Primer")
        #expect(detail.images.isEmpty)
    }

    @Test func testYouTubePlaylist() throws {
        let url = URL(string: "https://www.youtube.com/playlist?list=PL123")!
        let html = """
            <html><head><script nonce="x">var ytInitialData = {"contents":{"twoColumnBrowseResultsRenderer":{"tabs":[{"tabRenderer":{"content":{"sectionListRenderer":{"contents":[{"itemSectionRenderer":{"contents":[{"playlistVideoListRenderer":{"contents":[
             {"playlistVideoRenderer":{"videoId":"afIOXq040dM","title":{"runs":[{"text":"Sharkey's Shootout {gameplay}"}]},"shortBylineText":{"runs":[{"text":"AKM's Pinball Videos"}]}}},
             {"playlistVideoRenderer":{"videoId":"zfWr6veFgaQ","title":{"simpleText":"Sharkeys Shootout Minutorial"},"shortBylineText":{"runs":[{"text":"chuck"},{"text":"wurt"}]}}},
             {"continuationItemRenderer":{"continuationEndpoint":{}}}
            ]}}]}}]}}}}]}}};</script>
            <script>var other = {"a": 1};</script></head></html>
            """

        let result = try YouTubeScanner().scanList(url: url, content: html, kind: .tutorial)

        #expect(result.list.count == 2)
        #expect(result.list[0].url.absoluteString == "https://www.youtube.com/watch?v=afIOXq040dM")
        #expect(result.list[0].name == "Sharkey's Shootout {gameplay}")
        #expect(result.list[0].author == "AKM's Pinball Videos")
        #expect(result.list[0].kind == .tutorial)
        #expect(result.list[1].name == "Sharkeys Shootout Minutorial")
        #expect(result.list[1].author == "chuckwurt")
    }

    @Test func testYouTubePlaylistNoData() throws {
        let url = URL(string: "https://www.youtube.com/playlist?list=PL123")!
        let result = try YouTubeScanner().scanList(
            url: url, content: "<html></html>", kind: .tutorial)
        #expect(result.list.isEmpty)
    }
}
