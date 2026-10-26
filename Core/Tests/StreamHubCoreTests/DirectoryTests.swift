import XCTest
@testable import StreamHubCore

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
}
