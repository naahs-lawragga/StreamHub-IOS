import Foundation
import StreamHubCore

struct ViewingRequest: Sendable {
    let title: MediaTitle
    let episode: Episode?
    let region: String
}

enum ViewingMethod: Sendable { case browser, native }
enum ViewingEvidence: String, Sendable {
    case metadataReported = "Reported title availability"
    case userAuthorized = "Your authorized stream"
    case unverified = "Unverified website"
}

struct ViewingOption: Identifiable, Sendable {
    let id: String
    let name: String
    let detail: String
    let url: URL
    let method: ViewingMethod
    let evidence: ViewingEvidence
}

protocol ViewingProvider: Sendable {
    var identifier: String { get }
    func options(for request: ViewingRequest) async throws -> [ViewingOption]
}

/// TMDB IDs provide exact title matching. TMDB does not supply native media URLs.
struct TMDBViewingProvider: ViewingProvider {
    let client: TMDBClient
    let identifier = "tmdb-justwatch"
    func options(for request: ViewingRequest) async throws -> [ViewingOption] {
        let providers = try await client.watchProviders(for: request.title, region: request.region)
        return providers.map { provider in
            ViewingOption(id: "tmdb-\(provider.id)-\(provider.category)", name: provider.name,
                detail: "\(provider.category.capitalized) · \(provider.region) · Open TMDB viewing guide",
                url: provider.url, method: .browser, evidence: .metadataReported)
        }
    }
}

struct ProviderResult: Sendable {
    var options: [ViewingOption]
    var errors: [String]
}

/// At most three provider adapters run at once. Each adapter must use finite network timeouts.
struct ProviderRegistry: Sendable {
    let providers: [any ViewingProvider]
    func options(for request: ViewingRequest) async -> ProviderResult {
        await withTaskGroup(of: ProviderResult.self) { group in
            var next = 0
            func enqueue(_ provider: any ViewingProvider) {
                group.addTask {
                    do {
                        try Task.checkCancellation()
                        return ProviderResult(options: try await provider.options(for: request), errors: [])
                    } catch is CancellationError {
                        return ProviderResult(options: [], errors: [])
                    } catch {
                        return ProviderResult(options: [], errors: [error.localizedDescription])
                    }
                }
            }
            for provider in providers.prefix(3) { enqueue(provider); next += 1 }
            var result = ProviderResult(options: [], errors: [])
            for await partial in group {
                result.options += partial.options
                result.errors += partial.errors
                if next < providers.count, !Task.isCancelled {
                    enqueue(providers[next]); next += 1
                }
            }
            return result
        }
    }
}

enum AuthorizedStreamPolicy {
    static func validate(_ text: String) -> URL? {
        guard let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme?.lowercased() == "https", let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil else { return nil }
        // Some authorized HLS endpoints have no extension; AVPlayer decides format support.
        return url
    }
}
