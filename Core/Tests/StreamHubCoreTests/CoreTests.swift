import XCTest
@testable import StreamHubCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class CoreTests: XCTestCase {
    private func directory() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true) }
    private let movieJSON = #"{"page":1,"total_pages":3,"results":[{"id":42,"title":"Original Film","overview":"An adventure","poster_path":"/poster.jpg","vote_average":8.2,"release_date":"2026-01-02"}]}"#
    func testMovieAndTelevisionParsing() throws {
        let data = Data(#"{"page":2,"total_pages":5,"results":[{"id":1,"media_type":"movie","title":"Film","release_date":"2026-01-01"},{"id":1,"media_type":"tv","name":"Show","first_air_date":"2025-02-01"},{"id":2,"media_type":"person","name":"Actor"}]}"#.utf8)
        let page = try JSONDecoder().decode(MediaPage.self, from: data)
        XCTAssertEqual(page.results.count, 2)
        XCTAssertEqual(page.results.map(\.key), ["movie/1", "tv/1"])
        XCTAssertEqual(page.results.last?.year, "2025")
        XCTAssertEqual(page.page, 2)
    }
    func testTitleRoundTripPreservesTelevisionKind() throws {
        let title = MediaTitle(id: 4, kind: .tv, title: "A Series")
        let restored = try JSONDecoder().decode(MediaTitle.self, from: JSONEncoder().encode(title))
        XCTAssertEqual(restored, title)
        XCTAssertNil(MediaTitle.imageURL("https://evil.example/picture.jpg"))
        XCTAssertNil(MediaTitle.imageURL("/../escape"))
    }
    func testSearchEncodesQueryAndDoesNotExposeTokenInURL() async throws {
        let transport = StubTransport([HTTPResult(data: Data(movieJSON.utf8), statusCode: 200)])
        let client = TMDBClient(token: "secret-token", transport: transport, cache: MetadataCache(directory: directory()))
        let result = try await client.search("star & moon", page: 2)
        XCTAssertEqual(result.results.first?.displayTitle, "Original Film")
        let requests = await transport.requests
        XCTAssertEqual(requests.count, 1)
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer secret-token")
        let items = URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?.queryItems
        XCTAssertEqual(items?.first(where: { $0.name == "query" })?.value, "star & moon")
        XCTAssertEqual(items?.first(where: { $0.name == "page" })?.value, "2")
        XCTAssertFalse(request.url!.absoluteString.contains("secret-token"))
        XCTAssertEqual(request.timeoutInterval, 20)
    }
    func testEmptySearchDoesNotRequestNetwork() async throws {
        let transport = StubTransport([])
        let client = TMDBClient(token: "", transport: transport, cache: MetadataCache(directory: directory()))
        let page = try await client.search("   ")
        XCTAssertTrue(page.results.isEmpty)
        let requests = await transport.requests
        XCTAssertTrue(requests.isEmpty)
    }
    func testFreshCacheAvoidsRepeatedRequest() async throws {
        let transport = StubTransport([HTTPResult(data: Data(movieJSON.utf8), statusCode: 200)])
        let client = TMDBClient(token: "token", transport: transport, cache: MetadataCache(directory: directory()))
        _ = try await client.titles(.popularMovies)
        _ = try await client.titles(.popularMovies)
        let requests = await transport.requests
        XCTAssertEqual(requests.count, 1)
    }
    func testRateLimitRetriesThenSucceeds() async throws {
        let transport = StubTransport([
            HTTPResult(data: Data(), statusCode: 429, headers: ["Retry-After": "0"]),
            HTTPResult(data: Data(movieJSON.utf8), statusCode: 200)
        ])
        let client = TMDBClient(token: "token", transport: transport, cache: MetadataCache(directory: directory()))
        let page = try await client.titles(.popularMovies)
        XCTAssertEqual(page.results.count, 1)
        let requests = await transport.requests
        XCTAssertEqual(requests.count, 2)
    }
    func testLongRetryAfterDoesNotImmediatelyRetry() async throws {
        let transport = StubTransport([HTTPResult(data: Data(), statusCode: 429, headers: ["Retry-After": "120"])])
        let client = TMDBClient(token: "token", transport: transport, cache: MetadataCache(directory: directory()))
        do { _ = try await client.titles(.popularMovies); XCTFail("Expected rate limit") }
        catch { XCTAssertEqual(error as? APIError, .rateLimited) }
        let requests = await transport.requests
        XCTAssertEqual(requests.count, 1)
    }
    func testOfflineUsesStaleCacheWithoutCredential() async throws {
        let cache = MetadataCache(directory: directory())
        var url = URLComponents(string: "https://api.themoviedb.org/3/movie/popular")!
        url.queryItems = [URLQueryItem(name: "page", value: "1"), URLQueryItem(name: "language", value: Locale.preferredLanguages.first ?? "en-US")]
        await cache.put(Data(movieJSON.utf8), for: url.url!.absoluteString, savedAt: Date(timeIntervalSince1970: 0))
        let transport = StubTransport([])
        let client = TMDBClient(token: "", transport: transport, cache: cache)
        let page = try await client.titles(.popularMovies)
        XCTAssertEqual(page.results.first?.id, 42)
        let requests = await transport.requests
        XCTAssertTrue(requests.isEmpty)
    }
    func testUnauthorizedDoesNotRetry() async throws {
        let transport = StubTransport([HTTPResult(data: Data(), statusCode: 401)])
        let client = TMDBClient(token: "bad-token", transport: transport, cache: MetadataCache(directory: directory()))
        do { _ = try await client.titles(.popularMovies); XCTFail("Expected failure") }
        catch { XCTAssertEqual(error as? APIError, .unauthorized) }
        let requests = await transport.requests
        XCTAssertEqual(requests.count, 1)
    }
    func testCancellationPropagates() async throws {
        let client = TMDBClient(token: "token", transport: SlowTransport(), cache: MetadataCache(directory: directory()))
        let task = Task { try await client.titles(.popularMovies) }
        task.cancel()
        do { _ = try await task.value; XCTFail("Expected cancellation") }
        catch { XCTAssertTrue(error is CancellationError) }
    }
    func testProviderMetadataIsTitleLevelAndRegionSpecific() async throws {
        let payload = #"{"results":{"US":{"link":"https://www.themoviedb.org/movie/42/watch?locale=US","flatrate":[{"provider_id":7,"provider_name":"Example","logo_path":"/logo.jpg"}],"buy":[{"provider_id":7,"provider_name":"Example"}]}}}"#
        let transport = StubTransport([HTTPResult(data: Data(payload.utf8), statusCode: 200)])
        let client = TMDBClient(token: "token", transport: transport, cache: MetadataCache(directory: directory()))
        let providers = try await client.watchProviders(for: MediaTitle(id: 42, kind: .movie, title: "Film"), region: "us")
        XCTAssertEqual(providers.count, 1)
        XCTAssertEqual(providers.first?.region, "US")
        XCTAssertEqual(providers.first?.category, "Subscription")
        XCTAssertEqual(providers.first?.url.host, "www.themoviedb.org")
    }
    func testProviderRejectsUnexpectedDestination() async throws {
        let payload = #"{"results":{"US":{"link":"https://untrusted.example/watch","flatrate":[{"provider_id":7,"provider_name":"Example"}]}}}"#
        let client = TMDBClient(token: "token", transport: StubTransport([HTTPResult(data: Data(payload.utf8), statusCode: 200)]), cache: MetadataCache(directory: directory()))
        let providers = try await client.watchProviders(for: MediaTitle(id: 42, kind: .movie, title: "Film"), region: "US")
        XCTAssertTrue(providers.isEmpty)
    }
    func testLibraryAtomicPersistenceAndHistoryBounds() async throws {
        let file = directory().appendingPathComponent("library.json")
        let store = LibraryStore(fileURL: file)
        let title = MediaTitle(id: 42, kind: .movie, title: "Saved")
        var snapshot = LibrarySnapshot(watchlist: [title], searchHistory: (0..<50).map(String.init))
        snapshot.bookmarks = [WebsiteBookmark(name: "Example", url: URL(string: "https://example.com")!)]
        snapshot.playback = [PlaybackRecord(title: title, streamURL: URL(string: "https://example.com/video.m3u8")!, position: 45, duration: 90)]
        snapshot.selectedSeasons = ["tv/10": 2]
        try await store.save(snapshot)
        let restored = try await LibraryStore(fileURL: file).load()
        XCTAssertEqual(restored.watchlist, [title])
        XCTAssertEqual(restored.searchHistory.count, 30)
        XCTAssertEqual(restored.bookmarks.count, 1)
        XCTAssertEqual(restored.playback.first?.progress, 0.5)
        XCTAssertEqual(restored.selectedSeasons["tv/10"], 2)
    }
    func testPersistenceDoesNotSilentlyOverwriteCorruption() async throws {
        let file = directory().appendingPathComponent("library.json")
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not-json".utf8).write(to: file)
        do { _ = try await LibraryStore(fileURL: file).load(); XCTFail("Expected decode failure") } catch { }
        XCTAssertEqual(try String(contentsOf: file), "not-json")
    }
    func testOlderLibraryFieldsMigrateToDefaults() throws {
        let snapshot = try JSONDecoder().decode(LibrarySnapshot.self, from: Data(#"{"watchlist":[]}"#.utf8))
        XCTAssertTrue(snapshot.browserHistory.isEmpty)
        XCTAssertNil(snapshot.lastBrowserURL)
    }
    func testMovieDetailsAndTrailerParsing() async throws {
        let payload = #"{"id":42,"title":"Film","runtime":120,"genres":[{"id":1,"name":"Drama"}],"credits":{"cast":[{"id":3,"name":"Actor","character":"Hero"}]},"videos":{"results":[{"id":"abc","key":"trailer_key","name":"Trailer","site":"YouTube","type":"Trailer","official":true}]},"similar":{"page":1,"total_pages":1,"results":[{"id":8,"title":"Other"}]}}"#
        let client = TMDBClient(token: "token", transport: StubTransport([HTTPResult(data: Data(payload.utf8), statusCode: 200)]), cache: MetadataCache(directory: directory()))
        let details = try await client.details(for: MediaTitle(id: 42, kind: .movie, title: "Film"))
        XCTAssertEqual(details.runtime, 120)
        XCTAssertEqual(details.genres.first?.name, "Drama")
        XCTAssertEqual(details.cast.first?.character, "Hero")
        XCTAssertEqual(details.trailers.first?.url?.host, "www.youtube.com")
        XCTAssertEqual(details.similar.first?.kind, .movie)
    }
    func testTelevisionEpisodeMetadataAndEndpoint() async throws {
        let payload = #"{"id":9,"name":"Season 2","episodes":[{"id":90,"name":"Pilot","overview":"Episode description","season_number":2,"episode_number":1,"runtime":48,"still_path":"/episode.jpg"}]}"#
        let transport = StubTransport([HTTPResult(data: Data(payload.utf8), statusCode: 200)])
        let client = TMDBClient(token: "token", transport: transport, cache: MetadataCache(directory: directory()))
        let season = try await client.season(showID: 10, number: 2)
        XCTAssertEqual(season.episodes.first?.episodeNumber, 1)
        XCTAssertEqual(season.episodes.first?.runtime, 48)
        let requests = await transport.requests
        XCTAssertEqual(requests.first?.url?.path, "/3/tv/10/season/2")
    }
    func testMalformedMetadataFailsWithoutInventingResults() async throws {
        let transport = StubTransport([HTTPResult(data: Data(#"{"results":"invalid"}"#.utf8), statusCode: 200)])
        let client = TMDBClient(token: "token", transport: transport, cache: MetadataCache(directory: directory()))
        do { _ = try await client.titles(.popularMovies); XCTFail("Expected decoding failure") }
        catch { XCTAssertTrue(error is DecodingError) }
    }
    func testPlaybackProgressRejectsNonfiniteInput() {
        let record = PlaybackRecord(title: MediaTitle(id: 1, kind: .movie, title: "Film"), streamURL: URL(string: "https://example.com/video.mp4")!, position: .infinity, duration: .nan)
        XCTAssertEqual(record.position, 0)
        XCTAssertEqual(record.duration, 0)
        XCTAssertEqual(record.progress, 0)
        XCTAssertFalse(record.isFinished)
    }
}
private actor StubTransport: HTTPTransport {
    var responses: [HTTPResult]
    var requests: [URLRequest] = []
    init(_ responses: [HTTPResult]) { self.responses = responses }
    func data(for request: URLRequest) async throws -> HTTPResult {
        requests.append(request)
        guard !responses.isEmpty else { throw URLError(.notConnectedToInternet) }
        return responses.removeFirst()
    }
}
private struct SlowTransport: HTTPTransport {
    func data(for request: URLRequest) async throws -> HTTPResult {
        try await Task.sleep(nanoseconds: 60_000_000_000)
        throw URLError(.timedOut)
    }
}
