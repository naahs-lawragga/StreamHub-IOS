import XCTest
@testable import StreamHubCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class DirectoryTests: XCTestCase {
    func testCategoriesDeduplicationAndUnsafeLinks() {
        let input = """
        ## ▷ Legal video
        * **[Example](https://example.org/watch)** - Videos
        * [Example again](https://example.org/watch)
        * [Unsafe](javascript:alert)
        * [Cleartext](http://example.net)
        * [Credentials](https://user:pass@example.net)
        ## Documentaries
        * [Second](https://example.net/) / [Mirror](https://mirror.net)
        """
        let entries = DirectoryParser.parse(input)
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries.first?.name, "Example")
        XCTAssertEqual(entries.first?.category, "Legal video")
        XCTAssertEqual(entries.last?.category, "Documentaries")
    }
    func testEmptyOrChangedFormatDoesNotInventSites() {
        XCTAssertTrue(DirectoryParser.parse("No links here").isEmpty)
    }
    func testDirectoryRefreshRetainsCacheWhenNetworkFails() async throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("fmhy.json")
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let online = directorySession(DirectoryOnlineProtocol.self)
        let offline = directorySession(DirectoryOfflineProtocol.self)
        defer { online.invalidateAndCancel(); offline.invalidateAndCancel() }
        let first = try await DirectoryClient(fileURL: file, session: online).fetch(force: true)
        XCTAssertEqual(first.entries.map(\.name), ["Example"])
        XCTAssertFalse(first.isOffline)
        let saved = try Data(contentsOf: file)
        let client = DirectoryClient(fileURL: file, session: offline)
        let freshCache = try await client.fetch()
        XCTAssertEqual(freshCache.entries, first.entries)
        XCTAssertFalse(freshCache.isOffline, "Fresh disk cache should avoid a network request")
        let failedRefresh = try await client.fetch(force: true)
        XCTAssertEqual(failedRefresh.entries, first.entries)
        XCTAssertTrue(failedRefresh.isOffline)
        XCTAssertEqual(failedRefresh.fetchedAt, first.fetchedAt)
        XCTAssertEqual(try Data(contentsOf: file), saved, "An unsuccessful refresh must not overwrite the saved directory")
    }

    func testDirectoryFailureWithoutCacheDoesNotInventDestinations() async {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("fmhy.json")
        let offline = directorySession(DirectoryOfflineProtocol.self)
        defer { offline.invalidateAndCancel() }
        do {
            _ = try await DirectoryClient(fileURL: file, session: offline).fetch(force: true)
            XCTFail("Expected network failure")
        } catch {
            XCTAssertEqual((error as? URLError)?.code, .notConnectedToInternet)
            XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
        }
    }

    private func directorySession(_ protocolClass: AnyClass) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [protocolClass]
        return URLSession(configuration: configuration)
    }

}


private final class DirectoryOnlineProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("## Legal video\n* [Example](https://example.org/watch)".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

private final class DirectoryOfflineProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() { client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet)) }
    override func stopLoading() {}
}
