import XCTest
import StreamHubCore
@testable import StreamHub

final class SourceSelectionTests: XCTestCase {
    func testConfiguredWebsitesFirstFavoritesThenDirectoryWithoutDuplicates() {
        let first = BrowserEntry(title: "My website", url: URL(string: "https://saved.example/path")!)
        let favorite = BrowserEntry(title: "My favorite", url: URL(string: "https://favorite.example")!)
        let directory = DirectoryParser.parse("""
        ## Websites
        * [Duplicate saved site](https://saved.example/path)
        * [Directory first](https://directory.example)
        * [Favorite directory](https://directory-favorite.example)
        """)
        let model = selection(configured: [first, favorite], favorites: [favorite.id], directory: directory,
            directoryFavorites: ["https://directory-favorite.example"])
        XCTAssertEqual(model.websites.map(\.name), ["My favorite", "My website", "Favorite directory", "Directory first"])
        XCTAssertEqual(model.websites.map(\.isConfigured), [true, true, false, false])
        XCTAssertEqual(model.directoryWebsiteCount, 2)
        XCTAssertTrue(model.websites.first!.isFavorite)
    }

    func testDirectoryOptInAndPreviewLimitNeverHideConfiguredSites() {
        let saved = BrowserEntry(title: "Saved", url: URL(string: "https://saved.example")!)
        let directory = DirectoryParser.parse((0..<20).map { "* [Site \($0)](https://directory.example/\($0))" }.joined(separator: "\n"))
        let enabled = selection(configured: [saved], directory: directory)
        XCTAssertEqual(enabled.websites.count, 13)
        XCTAssertEqual(enabled.directoryWebsiteCount, 20)
        XCTAssertTrue(enabled.websites.first!.isConfigured)
        let disabled = selection(configured: [saved], directory: directory, enabled: false)
        XCTAssertEqual(disabled.websites.map(\.url), [saved.url])
        XCTAssertEqual(disabled.directoryWebsiteCount, 0)
    }

    func testRentAndBuyFilterRetainsSubscriptionAndFreeOptions() {
        let options = ["Rent", "Buy", "Subscription", "Free", "With ads"].enumerated().map { index, category in
            ViewingOption(id: "provider-\(index)", name: "Provider", detail: category,
                url: URL(string: "https://www.themoviedb.org/movie/1/watch")!,
                method: .browser, evidence: .metadataReported, category: category)
        }
        let hidden = selection(options: options, hidePaid: true)
        XCTAssertEqual(hidden.officialOptions.compactMap(\.category), ["Subscription", "Free", "With ads"])
        XCTAssertEqual(selection(options: options).officialOptions.count, 5)
    }

    func testMovieAndEpisodeUseUnchangedBrowserDestinationAndKeepSelectedContext() {
        let website = BrowserEntry(title: "Browser destination", url: URL(string: "https://example.com/search?mode=all")!)
        let movie = ViewingRequest(title: MediaTitle(id: 7, kind: .movie, title: "Movie"), episode: nil, region: "US")
        let episode = Episode(id: 91, name: "Episode", seasonNumber: 2, episodeNumber: 3)
        let tv = ViewingRequest(title: MediaTitle(id: 8, kind: .tv, title: "TV"), episode: episode, region: "US")
        for request in [movie, tv] {
            let model = SourceSelection(request: request, configured: [website], configuredFavorites: [],
                directoryEntries: [], directoryFavorites: [], directoryEnabled: false,
                officialOptions: [], hidePaidRentals: true)
            XCTAssertEqual(model.websites.first?.url, website.url)
            XCTAssertEqual(model.request.title, request.title)
            XCTAssertEqual(model.request.episode, request.episode)
            XCTAssertTrue(model.officialOptions.isEmpty)
        }
    }

    func testEmptyAndUnsafeDestinationsDoNotCreateAvailabilityOptions() {
        let unsafe = BrowserEntry(title: "Unsafe", url: URL(string: "file:///private/video.mp4")!)
        let model = selection(configured: [unsafe])
        XCTAssertTrue(model.websites.isEmpty)
        XCTAssertTrue(model.officialOptions.isEmpty)
    }

    private func selection(configured: [BrowserEntry] = [], favorites: Set<UUID> = [],
        directory: [DirectoryEntry] = [], directoryFavorites: Set<String> = [], enabled: Bool = true,
        options: [ViewingOption] = [], hidePaid: Bool = false) -> SourceSelection {
        SourceSelection(request: ViewingRequest(title: MediaTitle(id: 1, kind: .movie, title: "A"), episode: nil, region: "US"),
            configured: configured, configuredFavorites: favorites, directoryEntries: directory,
            directoryFavorites: directoryFavorites, directoryEnabled: enabled,
            officialOptions: options, hidePaidRentals: hidePaid)
    }
}
