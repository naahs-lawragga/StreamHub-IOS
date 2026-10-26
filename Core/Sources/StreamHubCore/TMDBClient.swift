import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum TMDBFeed: String, CaseIterable, Sendable {
    case trendingMovies, trendingTV, popularMovies, popularTV, newReleases, topRated
    var path: String {
        switch self {
        case .trendingMovies: return "trending/movie/day"
        case .trendingTV: return "trending/tv/day"
        case .popularMovies: return "movie/popular"
        case .popularTV: return "tv/popular"
        case .newReleases: return "movie/now_playing"
        case .topRated: return "movie/top_rated"
        }
    }
    var kind: MediaKind { self == .trendingTV || self == .popularTV ? .tv : .movie }
}

public actor TMDBClient {
    private let token: String
    private let transport: any HTTPTransport
    private let cache: MetadataCache
    public init(token: String, transport: any HTTPTransport = URLSessionTransport(), cache: MetadataCache = MetadataCache()) {
        self.token = token.trimmingCharacters(in: .whitespacesAndNewlines); self.transport = transport; self.cache = cache
    }
    public func titles(_ feed: TMDBFeed, page: Int = 1, forceRefresh: Bool = false) async throws -> MediaPage {
        let response: MediaPage = try await request(path: feed.path, query: pageQuery(page), maximumAge: forceRefresh ? 0 : 6 * 60 * 60)
        return response.settingKind(feed.kind)
    }
    public func search(_ query: String, page: Int = 1) async throws -> MediaPage {
        let clean = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return MediaPage(results: []) }
        return try await request(path: "search/multi", query: pageQuery(page) + [URLQueryItem(name: "query", value: clean), URLQueryItem(name: "include_adult", value: "false")])
    }
    public func details(for title: MediaTitle) async throws -> TitleDetails {
        let response: DetailsPayload = try await request(path: title.key, query: [URLQueryItem(name: "append_to_response", value: "credits,videos,similar")])
        var resolved = response.title; resolved.kind = title.kind
        return TitleDetails(title: resolved, runtime: response.runtime ?? response.episodeRunTime?.first,
                            genres: response.genres ?? [], cast: Array((response.credits?.cast ?? []).prefix(30)),
                            seasons: response.seasons ?? [], trailers: (response.videos?.results ?? []).filter { $0.type == "Trailer" && $0.url != nil },
                            similar: (response.similar?.settingKind(title.kind).results ?? []))
    }
    public func recommendations(for title: MediaTitle, page: Int = 1) async throws -> MediaPage {
        let response: MediaPage = try await request(path: title.key + "/recommendations", query: pageQuery(page))
        return response.settingKind(title.kind)
    }
    public func season(showID: Int, number: Int) async throws -> SeasonDetails {
        guard showID > 0, number >= 0 else { throw APIError.invalidRequest }
        return try await request(path: "tv/\(showID)/season/\(number)")
    }
    public func watchProviders(for title: MediaTitle, region: String) async throws -> [WatchProvider] {
        let region = region.uppercased()
        guard region.count == 2, region.unicodeScalars.allSatisfy({ CharacterSet.uppercaseLetters.contains($0) && $0.isASCII }) else { throw APIError.invalidRequest }
        let response: ProviderPayload = try await request(path: title.key + "/watch/providers", maximumAge: 60 * 60)
        guard let local = response.results[region], let link = local.link, link.scheme == "https", link.host == "www.themoviedb.org" || link.host == "themoviedb.org" else { return [] }
        var result: [WatchProvider] = []
        var seen = Set<Int>()
        for (label, providers) in [("Subscription", local.flatrate), ("Free", local.free), ("With ads", local.ads), ("Rent", local.rent), ("Buy", local.buy)] {
            for provider in providers ?? [] where seen.insert(provider.id).inserted {
                result.append(WatchProvider(id: provider.id, name: provider.name, logoURL: MediaTitle.imageURL(provider.logoPath, size: "w92"), url: link, category: label, region: region))
            }
        }
        return result
    }
    public func clearCache() async throws { try await cache.clear() }
    private func pageQuery(_ page: Int) -> [URLQueryItem] { [URLQueryItem(name: "page", value: String(max(1, min(500, page))))] }
    private func request<T: Decodable>(path: String, query: [URLQueryItem] = [], maximumAge: TimeInterval = 6 * 60 * 60) async throws -> T {
        try Task.checkCancellation()
        guard !path.contains(".."), var components = URLComponents(string: "https://api.themoviedb.org/3/" + path) else { throw APIError.invalidRequest }
        components.queryItems = query + [URLQueryItem(name: "language", value: Locale.preferredLanguages.first ?? "en-US")]
        guard let url = components.url else { throw APIError.invalidRequest }
        let key = url.absoluteString
        let decoder = JSONDecoder()
        if let cached = await cache.data(for: key, maximumAge: maximumAge), let value = try? decoder.decode(T.self, from: cached) { return value }
        guard !token.isEmpty else {
            if let cached = await cache.data(for: key), let value = try? decoder.decode(T.self, from: cached) { return value }
            throw APIError.missingCredential
        }
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        do {
            for attempt in 0..<3 {
                try Task.checkCancellation()
                let response: HTTPResult
                do { response = try await transport.data(for: request) }
                catch {
                    if Task.isCancelled || (error as? URLError)?.code == .cancelled { throw CancellationError() }
                    if attempt < 2 { try await delay(seconds: Double(attempt + 1)); continue }
                    throw error
                }
                if response.statusCode == 401 || response.statusCode == 403 { throw APIError.unauthorized }
                if response.statusCode == 429 || (500...599).contains(response.statusCode) {
                    if attempt < 2 {
                        let retry = retryDelay(response.headers["retry-after"], fallback: Double(attempt + 1))
                        // Never retry earlier than a long server Retry-After instruction.
                        if retry > 10 { throw response.statusCode == 429 ? APIError.rateLimited : APIError.server(response.statusCode) }
                        try await delay(seconds: min(10, max(0, retry))); continue
                    }
                    throw response.statusCode == 429 ? APIError.rateLimited : APIError.server(response.statusCode)
                }
                guard (200...299).contains(response.statusCode) else { throw APIError.server(response.statusCode) }
                guard response.data.count <= 8 * 1024 * 1024 else { throw APIError.invalidResponse }
                let value = try decoder.decode(T.self, from: response.data)
                await cache.put(response.data, for: key)
                return value
            }
            throw APIError.invalidResponse
        } catch {
            if Task.isCancelled || error is CancellationError { throw CancellationError() }
            if error as? APIError == .unauthorized { throw error }
            if let cached = await cache.data(for: key), let value = try? decoder.decode(T.self, from: cached) { return value }
            throw error
        }
    }
    private func retryDelay(_ value: String?, fallback: Double) -> Double {
        guard let value else { return fallback }
        if let seconds = Double(value), seconds.isFinite { return max(0, seconds) }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return formatter.date(from: value).map { max(0, $0.timeIntervalSinceNow) } ?? fallback
    }
    private func delay(seconds: Double) async throws { try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000)) }
}
private extension MediaPage {
    func settingKind(_ kind: MediaKind) -> MediaPage {
        MediaPage(page: page, totalPages: totalPages, results: results.map { var title = $0; title.kind = kind; return title })
    }
}
private struct DetailsPayload: Decodable {
    let title: MediaTitle
    let runtime: Int?
    let episodeRunTime: [Int]?
    let genres: [Genre]?
    let credits: Credits?
    let videos: Videos?
    let seasons: [SeasonSummary]?
    let similar: MediaPage?
    struct Credits: Decodable { let cast: [CastMember] }
    struct Videos: Decodable { let results: [Trailer] }
    enum CodingKeys: String, CodingKey { case runtime, genres, credits, videos, seasons, similar; case episodeRunTime = "episode_run_time" }
    init(from decoder: Decoder) throws {
        title = try MediaTitle(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        runtime = try c.decodeIfPresent(Int.self, forKey: .runtime)
        episodeRunTime = try c.decodeIfPresent([Int].self, forKey: .episodeRunTime)
        genres = try c.decodeIfPresent([Genre].self, forKey: .genres)
        credits = try c.decodeIfPresent(Credits.self, forKey: .credits)
        videos = try c.decodeIfPresent(Videos.self, forKey: .videos)
        seasons = try c.decodeIfPresent([SeasonSummary].self, forKey: .seasons)
        similar = try c.decodeIfPresent(MediaPage.self, forKey: .similar)
    }
}
private struct ProviderPayload: Decodable {
    let results: [String: Region]
    struct Region: Decodable {
        let link: URL?
        let flatrate: [Provider]?
        let free: [Provider]?
        let ads: [Provider]?
        let rent: [Provider]?
        let buy: [Provider]?
    }
    struct Provider: Decodable {
        let id: Int
        let name: String
        let logoPath: String?
        enum CodingKeys: String, CodingKey { case id = "provider_id", name = "provider_name", logoPath = "logo_path" }
    }
}
