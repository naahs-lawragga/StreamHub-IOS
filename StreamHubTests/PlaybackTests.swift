import XCTest
import StreamHubCore
@testable import StreamHub

final class PlaybackTests: XCTestCase {
    func testNativePolicyRejectsInsecureCredentialsAndExecutableSchemes() {
        for text in ["http://example.com/movie.mp4", "file:///tmp/movie.mp4", "javascript:alert(1)",
                     "https://user:password@example.com/video.m3u8", "https:///", ""] {
            XCTAssertNil(AuthorizedStreamPolicy.validate(text), text)
        }
        XCTAssertEqual(AuthorizedStreamPolicy.validate("https://example.com/video.m3u8?token=authorized")?.host, "example.com")
        XCTAssertNotNil(AuthorizedStreamPolicy.validate("https://example.com/authorized-stream"))
    }

    func testProviderFailureDoesNotDiscardOtherOptions() async {
        let request = ViewingRequest(title: MediaTitle(id: 1, kind: .movie, title: "A"), episode: nil, region: "US")
        let registry = ProviderRegistry(providers: [FailingProvider(), SuccessfulProvider(identifier: "one")])
        let result = await registry.options(for: request)
        XCTAssertEqual(result.options.count, 1)
        XCTAssertEqual(result.errors.count, 1)
        XCTAssertEqual(result.options.first?.evidence, .unverified)
    }

    func testConcurrentProviderChecksAreBounded() async {
        let counter = ConcurrencyCounter()
        let registry = ProviderRegistry(providers: (0..<12).map { CountingProvider(identifier: "\($0)", counter: counter) })
        let request = ViewingRequest(title: MediaTitle(id: 1, kind: .movie, title: "A"), episode: nil, region: "US")
        _ = await registry.options(for: request)
        let peak = await counter.peak
        XCTAssertLessThanOrEqual(peak, 3)
        XCTAssertGreaterThan(peak, 1)
    }

    @MainActor func testInvalidPlaybackShowsErrorWithoutNetwork() {
        let player = PlayerModel(url: URL(string: "file:///tmp/movie.mp4")!)
        player.start(resumeAt: 0, speed: 1) { _, _ in XCTFail("Invalid playback must not record progress") }
        XCTAssertNotNil(player.error)
        XCTAssertFalse(player.buffering)
        player.stop()
    }
}

private struct FailingProvider: ViewingProvider {
    let identifier = "failing"
    func options(for request: ViewingRequest) async throws -> [ViewingOption] { throw URLError(.timedOut) }
}
private struct SuccessfulProvider: ViewingProvider {
    let identifier: String
    func options(for request: ViewingRequest) async throws -> [ViewingOption] {
        [ViewingOption(id: identifier, name: "Example", detail: "User website", url: URL(string: "https://example.com")!, method: .browser, evidence: .unverified)]
    }
}
private actor ConcurrencyCounter {
    var current = 0
    var peak = 0
    func enter() { current += 1; peak = max(peak, current) }
    func leave() { current -= 1 }
}
private struct CountingProvider: ViewingProvider {
    let identifier: String
    let counter: ConcurrencyCounter
    func options(for request: ViewingRequest) async throws -> [ViewingOption] {
        await counter.enter()
        try await Task.sleep(nanoseconds: 10_000_000)
        await counter.leave()
        return []
    }
}
