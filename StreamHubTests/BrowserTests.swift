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

    @MainActor
    func testLegacyBookmarksMigrateFavoritesWithoutRewritingSavedData() throws {
        let suite = "StreamHubTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let first = BrowserEntry(title: "First", url: URL(string: "https://first.example")!)
        let second = BrowserEntry(title: "Second", url: URL(string: "https://second.example")!)
        let bookmarkBytes = try JSONEncoder().encode([first, second])
        let historyBytes = try JSONEncoder().encode([second])
        defaults.set(bookmarkBytes, forKey: "browser.bookmarks")
        defaults.set(historyBytes, forKey: "browser.history")
        defaults.set("GB", forKey: "watchRegion")
        defaults.set(1.25, forKey: "defaultPlaybackSpeed")
        defaults.set("LiveContainer", forKey: "installationMethod")

        let browser = BrowserData(defaults: defaults)
        XCTAssertEqual(browser.bookmarks, [first, second])
        XCTAssertEqual(browser.favoriteWebsiteIDs, Set([first.id, second.id]))
        XCTAssertEqual(defaults.data(forKey: "browser.bookmarks"), bookmarkBytes)
        browser.toggleWebsiteFavorite(first.id)
        XCTAssertEqual(browser.sortedWebsites.map(\.id), [second.id, first.id])
        let restored = BrowserData(defaults: defaults)
        XCTAssertFalse(restored.isFavoriteWebsite(first.id))
        XCTAssertTrue(restored.isFavoriteWebsite(second.id))
        XCTAssertTrue(restored.addWebsite(title: "Temporary", url: URL(string: "https://temporary.example")!))
        let temporaryID = try XCTUnwrap(restored.bookmarks.first?.id)
        XCTAssertTrue(restored.updateWebsite(temporaryID, title: "Changed", url: URL(string: "https://changed.example")!))
        restored.removeBookmark(temporaryID)
        XCTAssertEqual(restored.bookmarks, [first, second])
        XCTAssertEqual(restored.history, [second])
        XCTAssertEqual(defaults.data(forKey: "browser.history"), historyBytes)
        XCTAssertEqual(defaults.string(forKey: "watchRegion"), "GB")
        XCTAssertEqual(defaults.double(forKey: "defaultPlaybackSpeed"), 1.25)
        XCTAssertEqual(defaults.string(forKey: "installationMethod"), "LiveContainer")
    }

    @MainActor
    func testWebsiteEditingRetainsIdentityAndFavoritesAndPersistsRemoval() throws {
        let suite = "StreamHubTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let browser = BrowserData(defaults: defaults)
        let url = URL(string: "https://example.com/first")!
        XCTAssertTrue(browser.addWebsite(title: " Original ", url: url, isFavorite: true))
        let original = try XCTUnwrap(browser.bookmarks.first)
        XCTAssertEqual(original.title, "Original")
        XCTAssertFalse(browser.addWebsite(title: "Duplicate", url: url))
        let replacement = URL(string: "https://example.com/updated")!
        XCTAssertTrue(browser.updateWebsite(original.id, title: "Updated", url: replacement))
        let restored = BrowserData(defaults: defaults)
        let edited = try XCTUnwrap(restored.bookmarks.first)
        XCTAssertEqual(edited.id, original.id)
        XCTAssertEqual(edited.visitedAt, original.visitedAt)
        XCTAssertEqual(edited.title, "Updated")
        XCTAssertEqual(edited.url, replacement)
        XCTAssertTrue(restored.isFavoriteWebsite(original.id))
        restored.removeBookmark(original.id)
        let empty = BrowserData(defaults: defaults)
        XCTAssertTrue(empty.bookmarks.isEmpty)
        XCTAssertTrue(empty.favoriteWebsiteIDs.isEmpty)
        XCTAssertTrue(empty.addWebsite(title: "New", url: url))
        XCTAssertFalse(try XCTUnwrap(empty.bookmarks.first).id == original.id)
        XCTAssertTrue(BrowserData(defaults: defaults).favoriteWebsiteIDs.isEmpty)
    }

    @MainActor
    func testWebsiteCRUDRejectsUnsafeInvalidAndDuplicateEdits() throws {
        let suite = "StreamHubTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let browser = BrowserData(defaults: defaults)
        let firstURL = URL(string: "https://first.example")!
        let secondURL = URL(string: "https://second.example")!
        XCTAssertFalse(browser.addWebsite(title: "Unsafe", url: URL(string: "file:///private/test")!))
        XCTAssertFalse(browser.addWebsite(title: "  ", url: firstURL))
        XCTAssertTrue(browser.addWebsite(title: "First", url: firstURL))
        let firstID = try XCTUnwrap(browser.bookmarks.first?.id)
        XCTAssertTrue(browser.addWebsite(title: "Second", url: secondURL))
        XCTAssertFalse(browser.updateWebsite(firstID, title: "Duplicate", url: secondURL))
        XCTAssertFalse(browser.updateWebsite(firstID, title: "Unsafe", url: URL(string: "javascript:alert(1)")!))
        XCTAssertFalse(browser.updateWebsite(firstID, title: " ", url: firstURL))
        XCTAssertEqual(browser.bookmarks.first(where: { $0.id == firstID })?.title, "First")
        XCTAssertEqual(browser.bookmarks.count, 2)
    }

}
