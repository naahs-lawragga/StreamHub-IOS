import XCTest
@testable import StreamHubCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class UpdatesTests: XCTestCase {
    func testNumericSemanticOrdering() throws {
        XCTAssertLessThan(try XCTUnwrap(SemanticVersion("1.9.9")), try XCTUnwrap(SemanticVersion("1.10.0")))
        XCTAssertLessThan(try XCTUnwrap(SemanticVersion("1.0.0-rc.9")), try XCTUnwrap(SemanticVersion("1.0.0-rc.10")))
        XCTAssertLessThan(try XCTUnwrap(SemanticVersion("1.0.0-rc.99")), try XCTUnwrap(SemanticVersion("1.0.0")))
        XCTAssertEqual(SemanticVersion("1.0.0+first"), SemanticVersion("1.0.0+second"))
        XCTAssertLessThan(try XCTUnwrap(SemanticVersion("1.0.0-999999999999999999999")), try XCTUnwrap(SemanticVersion("1.0.0-1000000000000000000000")))
    }

    func testRejectsMalformedSemanticVersions() {
        for value in ["", "v1.0.0", "1.0", "1.2.3.4", "01.2.3", "1.0.0-", "1.0.0-01", "1.0.0+", "1.0.0+meta+more", "1.0.0-hello world", "-1.0.0"] {
            XCTAssertNil(SemanticVersion(value), value)
        }
    }

    func testLatestCompatibleStableAndUpdateDetection() throws {
        let data = try feed(versions: [version("1.1.0"), version("1.10.0"), version("9.0.0-beta"), version("2.0.0", extra: ["minOSVersion": "26.0"])])
        let release = try UpdateFeed.latest(in: data, operatingSystem: "17.4")
        XCTAssertEqual(release.version, "1.10.0")
        XCTAssertTrue(UpdateFeed.isNewer(release, than: "1.2.0"))
        XCTAssertFalse(UpdateFeed.isNewer(release, than: "1.10.0"))
        XCTAssertFalse(UpdateFeed.isNewer(release, than: "2.0.0"))
        XCTAssertFalse(UpdateFeed.isNewer(release, than: "corrupt"))
        XCTAssertEqual(try UpdateFeed.latest(in: data, operatingSystem: "26.0").version, "2.0.0")
    }

    func testIdentityMustMatchExactlyOnce() throws {
        XCTAssertThrowsError(try UpdateFeed.latest(in: feed(bundle: "com.someoneelse.app")))
        let app: [String: Any] = ["bundleIdentifier": "com.streamhub.ios", "versions": [version("1.0.0")]]
        let duplicate = try JSONSerialization.data(withJSONObject: ["name": "StreamHub", "apps": [app, app]])
        XCTAssertThrowsError(try UpdateFeed.latest(in: duplicate))
    }

    func testInvalidMetadataRejected() throws {
        let invalid: [[String: Any]] = [
            ["downloadURL": "http://example.com/app.ipa"],
            ["downloadURL": "https://user:password@example.com/app.ipa"],
            ["downloadURL": "https://example.com/script.js"],
            ["size": 0], ["size": -1], ["size": "100"],
            ["date": "yesterday"], ["date": "2026-02-31"],
            ["minOSVersion": "seventeen"], ["maxOSVersion": "17.bad"],
            ["sha256": "invalid"], ["streamhubReleaseURL": "javascript:alert(1)"]
        ]
        for fields in invalid {
            XCTAssertThrowsError(try UpdateFeed.latest(in: feed(versions: [version("1.0.0", extra: fields)])), "\(fields)")
        }
        XCTAssertThrowsError(try UpdateFeed.latest(in: Data("{}".utf8)))
        XCTAssertThrowsError(try UpdateFeed.latest(in: Data(repeating: 0, count: 2_000_001)))
        XCTAssertThrowsError(try UpdateFeed.latest(in: feed(versions: [])))
    }

    func testDismissalAndSixHourInterval() {
        XCTAssertFalse(UpdateReminderPolicy.shouldPresent(version: "1.2.0", dismissedVersions: ["1.2.0"]))
        XCTAssertTrue(UpdateReminderPolicy.shouldPresent(version: "1.3.0", dismissedVersions: ["1.2.0"]))
        let now = Date(timeIntervalSince1970: 100_000)
        XCTAssertTrue(UpdateReminderPolicy.shouldCheck(lastAttempt: nil, now: now))
        XCTAssertFalse(UpdateReminderPolicy.shouldCheck(lastAttempt: now.addingTimeInterval(-21_599), now: now))
        XCTAssertTrue(UpdateReminderPolicy.shouldCheck(lastAttempt: now.addingTimeInterval(-21_600), now: now))
        XCTAssertTrue(UpdateReminderPolicy.shouldCheck(lastAttempt: now.addingTimeInterval(1), now: now))
    }

    func testOfflineCachedFeedCanBeParsed() throws {
        let data = try feed()
        let cached = try JSONDecoder().decode(UpdateRelease.self, from: JSONEncoder().encode(UpdateFeed.latest(in: data)))
        XCTAssertEqual(cached.version, "1.2.0")
        XCTAssertEqual(cached.size, 123456)
        XCTAssertEqual(cached.downloadURL.scheme, "https")
    }

    func testHTTPSValidationRejectsRelativeAndCredentialURLs() {
        for raw in ["file:///tmp/app.ipa", "http://example.com/app.ipa", "https://user@example.com/app.ipa", "/app.ipa"] {
            XCTAssertFalse(UpdateFeed.isSecureURL(URL(string: raw)!))
        }
        XCTAssertTrue(UpdateFeed.isSecureURL(URL(string: "https://example.com/app.ipa")!))
    }

    func testClientRejectsInsecureSourceBeforeNetwork() async {
        do {
            _ = try await UpdateClient().fetch(sourceURL: URL(string: "http://example.com/source.json")!, operatingSystem: "17.0")
            XCTFail("Expected HTTPS validation failure")
        } catch { XCTAssertTrue(error is UpdateError) }
    }

    func testOfflineNetworkFailureIsReported() async {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [OfflineUpdateProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        do {
            _ = try await UpdateClient(session: session).fetch(sourceURL: URL(string: "https://example.com/source.json")!, operatingSystem: "17.0")
            XCTFail("Expected an offline error")
        } catch {
            XCTAssertEqual((error as? URLError)?.code, .notConnectedToInternet)
        }
    }

    private func version(_ value: String, extra: [String: Any] = [:]) -> [String: Any] {
        var result: [String: Any] = ["version": value, "date": "2026-10-26", "downloadURL": "https://example.com/StreamHub.ipa", "size": 123456, "localizedDescription": "Improvements"]
        for (key, value) in extra { result[key] = value }
        return result
    }

    private func feed(bundle: String = "com.streamhub.ios", versions: [[String: Any]]? = nil) throws -> Data {
        try JSONSerialization.data(withJSONObject: ["name": "StreamHub", "apps": [["bundleIdentifier": bundle, "versions": versions ?? [version("1.2.0")]]]])
    }
}

private final class OfflineUpdateProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() { client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet)) }
    override func stopLoading() {}
}
