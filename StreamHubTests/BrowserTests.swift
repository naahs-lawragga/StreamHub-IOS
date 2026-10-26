import XCTest
@testable import StreamHub

final class BrowserTests: XCTestCase {
    func testAddressesDefaultToHTTPSAndRejectUnsafeSchemes() {
        XCTAssertEqual(WebAddress.parse("example.com/path")?.absoluteString, "https://example.com/path")
        XCTAssertEqual(WebAddress.parse(" https://example.com ")?.host, "example.com")
        XCTAssertNil(WebAddress.parse(""))
        XCTAssertNil(WebAddress.parse("not a domain"))
        XCTAssertNil(WebAddress.parse("file:///etc/passwd"))
        XCTAssertNil(WebAddress.parse("javascript:alert(1)"))
        XCTAssertNil(WebAddress.parse("data:text/html,hello"))
        XCTAssertNil(WebAddress.parse("https://username:password@example.com"))
        XCTAssertFalse(WebAddress.isWebURL(URL(string: "javascript:alert(1)")!))
        XCTAssertFalse(WebAddress.isWebURL(URL(string: "data:text/html,hello")!))
        XCTAssertTrue(WebAddress.isWebURL(URL(string: "https://example.com")!))
    }

    @MainActor
    func testBookmarksPersistAndToggleWithoutDuplicates() throws {
        let suite = "StreamHubTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let data = BrowserData(defaults: defaults)
        let url = URL(string: "https://example.com")!
        data.toggleBookmark(title: "Example", url: url)
        XCTAssertEqual(data.bookmarks.count, 1)
        let restored = BrowserData(defaults: defaults)
        XCTAssertEqual(restored.bookmarks.first?.url, url)
        restored.toggleBookmark(title: "Example", url: url)
        XCTAssertTrue(restored.bookmarks.isEmpty)
        XCTAssertTrue(BrowserData(defaults: defaults).bookmarks.isEmpty)
    }

    @MainActor
    func testHistoryIsBoundedDeduplicatedAndCleared() throws {
        let suite = "StreamHubTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let data = BrowserData(defaults: defaults)
        for index in 0..<120 {
            data.record(title: "Page \(index)", url: URL(string: "https://example.com/\(index)")!)
        }
        XCTAssertEqual(data.history.count, 100)
        let lastURL = URL(string: "https://example.com/119")!
        data.record(title: "Updated", url: lastURL)
        XCTAssertEqual(data.history.count, 100)
        XCTAssertEqual(data.history.first?.title, "Updated")
        XCTAssertEqual(defaults.string(forKey: "browser.lastURL"), lastURL.absoluteString)
        data.record(title: "Blocked", url: URL(string: "file:///private/test")!)
        XCTAssertEqual(data.history.count, 100)
        data.clearHistory()
        XCTAssertTrue(BrowserData(defaults: defaults).history.isEmpty)
        XCTAssertNil(defaults.string(forKey: "browser.lastURL"))
    }

    @MainActor
    func testInvalidBrowserURLProducesRecoverableError() {
        let model = BrowserModel(url: URL(string: "file:///not-allowed")!)
        XCTAssertNotNil(model.error)
        XCTAssertNil(model.webView.url)
        XCTAssertFalse(model.loading)
    }
}
