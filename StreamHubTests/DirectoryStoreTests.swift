import XCTest
import StreamHubCore
@testable import StreamHub

final class DirectoryStoreTests: XCTestCase {
    @MainActor func testExistingDirectoryFavoritesSurviveSharedStoreAndReload() throws {
        let suite = "directory-store-tests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let original: Set<String> = ["https://example.org/one", "https://example.org/two"]
        let data = try JSONEncoder().encode(original)
        defaults.set(data, forKey: "directoryFavorites")
        defaults.set(true, forKey: "fmhyEnabled")
        let store = DirectoryStore(defaults: defaults)
        XCTAssertEqual(store.favorites, original)
        XCTAssertEqual(defaults.data(forKey: "directoryFavorites"), data)
        let entry = DirectoryEntry(name: "Three", url: URL(string: "https://example.org/three")!, category: "Movies")
        store.toggleFavorite(entry)
        XCTAssertTrue(store.isFavorite(entry))
        XCTAssertEqual(DirectoryStore(defaults: defaults).favorites, original.union([entry.id]))
        store.toggleFavorite(entry)
        XCTAssertEqual(DirectoryStore(defaults: defaults).favorites, original)
        XCTAssertTrue(defaults.bool(forKey: "fmhyEnabled"))
    }

    @MainActor func testCreatingSharedDirectoryDoesNotOptUserInOrWriteData() throws {
        let suite = "directory-store-tests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = DirectoryStore(defaults: defaults)
        XCTAssertTrue(store.entries.isEmpty)
        XCTAssertTrue(store.favorites.isEmpty)
        XCTAssertFalse(store.isLoading)
        XCTAssertNil(defaults.object(forKey: "fmhyEnabled"))
        XCTAssertNil(defaults.object(forKey: "directoryFavorites"))
    }
}
