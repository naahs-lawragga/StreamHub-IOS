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
    var category: String? = nil

    var isPaidRentalOrPurchase: Bool {
        let normalized = category?.lowercased()
        return normalized == "rent" || normalized == "buy"
    }
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
                detail: "\(Self.categoryLabel(provider.category)) · \(provider.region) · Open TMDB viewing guide",
                url: provider.url, method: .browser, evidence: .metadataReported, category: provider.category)
        }
    }

    private static func categoryLabel(_ category: String) -> String {
        switch category.lowercased() {
        case "flatrate", "subscription": return "Subscription"
        case "rent": return "Rental"
        case "buy": return "Purchase"
        case "free": return "Free"
        case "ads", "with ads": return "With ads"
        default: return category.capitalized
        }
    }
}

/// A website is a browser destination. No title matching or availability is inferred.
struct StreamingWebsiteOption: Identifiable {
    var id: String { url.absoluteString }
    let name: String
    let url: URL
    let isFavorite: Bool
    let isConfigured: Bool
}

/// The same selection model serves movies, shows, and individual episode requests.
struct SourceSelection {
    let request: ViewingRequest
    let websites: [StreamingWebsiteOption]
    let officialOptions: [ViewingOption]
    let directoryWebsiteCount: Int

    init(request: ViewingRequest, configured: [BrowserEntry], configuredFavorites: Set<UUID>,
         directoryEntries: [DirectoryEntry], directoryFavorites: Set<String>, directoryEnabled: Bool,
         officialOptions: [ViewingOption], hidePaidRentals: Bool, directoryLimit: Int = 12) {
        self.request = request
        let configuredSorted = configured.enumerated().sorted {
            let lhs = configuredFavorites.contains($0.element.id)
            let rhs = configuredFavorites.contains($1.element.id)
            return lhs != rhs ? lhs : $0.offset < $1.offset
        }.map(\.element)
        var seen = Set<String>()
        var destinations: [StreamingWebsiteOption] = []
        for website in configuredSorted where WebAddress.isWebURL(website.url) {
            guard seen.insert(website.url.absoluteString).inserted else { continue }
            destinations.append(StreamingWebsiteOption(name: website.title, url: website.url,
                isFavorite: configuredFavorites.contains(website.id), isConfigured: true))
        }
        var directoryOptions: [StreamingWebsiteOption] = []
        if directoryEnabled {
            let sorted = directoryEntries.enumerated().sorted {
                let lhs = directoryFavorites.contains($0.element.id)
                let rhs = directoryFavorites.contains($1.element.id)
                return lhs != rhs ? lhs : $0.offset < $1.offset
            }.map(\.element)
            for entry in sorted where WebAddress.isWebURL(entry.url) {
                guard seen.insert(entry.url.absoluteString).inserted else { continue }
                directoryOptions.append(StreamingWebsiteOption(name: entry.name, url: entry.url,
                    isFavorite: directoryFavorites.contains(entry.id), isConfigured: false))
            }
        }
        directoryWebsiteCount = directoryOptions.count
        websites = destinations + directoryOptions.prefix(max(0, directoryLimit))
        self.officialOptions = officialOptions.filter { !hidePaidRentals || !$0.isPaidRentalOrPurchase }
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
