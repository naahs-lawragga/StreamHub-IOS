import XCTest
@testable import StreamHubCore

final class SourceInstallationLinkTests: XCTestCase {
    func testPublicSourceUsesDocumentedSchemeHostAndEncodedQuery() throws {
        let source = try XCTUnwrap(URL(string: "https://naahs-lawragga.github.io/StreamHub-IOS/source.json"))
        let link = try XCTUnwrap(SourceInstallationLink.liveContainer(sourceURL: source))
        XCTAssertEqual(link.absoluteString, "livecontainer://source?url=https%3A%2F%2Fnaahs-lawragga.github.io%2FStreamHub-IOS%2Fsource.json")
        XCTAssertEqual(link.scheme, "livecontainer")
        XCTAssertEqual(link.host, "source")
        XCTAssertEqual(URLComponents(url: link, resolvingAgainstBaseURL: false)?.queryItems?.first?.value, source.absoluteString)
    }

    func testNestedQueryPlusPercentUnicodeAndFragmentSurviveExactlyOneDecode() throws {
        for raw in [
            "https://example.com/source.json?channel=stable&name=a+b#latest",
            "https://example.com/path%20name/source.json?next=https%3A%2F%2Fexample.org%2Fa%3Fx%3D1%26y%3D2",
            "https://example.com/日本/source.json?q=red+black&symbol=%25#section"
        ] {
            let source = try XCTUnwrap(URL(string: raw))
            let link = try XCTUnwrap(SourceInstallationLink.liveContainer(sourceURL: source))
            let components = try XCTUnwrap(URLComponents(url: link, resolvingAgainstBaseURL: false))
            XCTAssertNil(components.fragment)
            XCTAssertEqual(components.queryItems?.count, 1)
            XCTAssertEqual(components.queryItems?.first?.name, "url")
            XCTAssertEqual(components.queryItems?.first?.value, source.absoluteString)
        }
    }

    func testInvalidOrInsecureSourcesCannotBecomeInstallerLinks() throws {
        for raw in ["http://example.com/source.json", "file:///tmp/source.json", "https://user:pass@example.com/source.json", "/source.json", "javascript:alert(1)"] {
            XCTAssertNil(SourceInstallationLink.liveContainer(sourceURL: try XCTUnwrap(URL(string: raw))), raw)
        }
    }
}
