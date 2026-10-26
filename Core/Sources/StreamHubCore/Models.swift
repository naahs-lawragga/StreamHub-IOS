import Foundation

public enum MediaKind: String, Codable, CaseIterable, Sendable { case movie, tv }

public struct MediaTitle: Codable, Hashable, Identifiable, Sendable {
    public let id: Int
    public var kind: MediaKind
    public let title: String
    public let overview: String
    public let posterPath: String?
    public let backdropPath: String?
    public let voteAverage: Double
    public let releaseDate: String?
    public var displayTitle: String { title }
    public var key: String { "\(kind.rawValue)/\(id)" }
    public var year: String { String((releaseDate ?? "").prefix(4)) }
    public var posterURL: URL? { Self.imageURL(posterPath, size: "w342") }
    public var backdropURL: URL? { Self.imageURL(backdropPath, size: "w1280") }
    public static func imageURL(_ path: String?, size: String = "w342") -> URL? {
        guard let path, path.hasPrefix("/"), !path.contains(".."), !path.contains("://") else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/\(size)\(path)")
    }
    public init(id: Int, kind: MediaKind, title: String, overview: String = "", posterPath: String? = nil, backdropPath: String? = nil, voteAverage: Double = 0, releaseDate: String? = nil) {
        self.id = id; self.kind = kind; self.title = title; self.overview = overview
        self.posterPath = posterPath; self.backdropPath = backdropPath; self.voteAverage = voteAverage; self.releaseDate = releaseDate
    }
    enum CodingKeys: String, CodingKey {
        case id, kind, title, name, overview
        case mediaType = "media_type", posterPath = "poster_path", backdropPath = "backdrop_path"
        case voteAverage = "vote_average", releaseDate = "release_date", firstAirDate = "first_air_date"
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        let movieTitle = try c.decodeIfPresent(String.self, forKey: .title)
        title = try movieTitle ?? c.decodeIfPresent(String.self, forKey: .name) ?? "Untitled"
        kind = try c.decodeIfPresent(MediaKind.self, forKey: .kind) ?? c.decodeIfPresent(MediaKind.self, forKey: .mediaType) ?? (movieTitle == nil ? .tv : .movie)
        overview = try c.decodeIfPresent(String.self, forKey: .overview) ?? ""
        posterPath = try c.decodeIfPresent(String.self, forKey: .posterPath)
        backdropPath = try c.decodeIfPresent(String.self, forKey: .backdropPath)
        voteAverage = try c.decodeIfPresent(Double.self, forKey: .voteAverage) ?? 0
        releaseDate = try c.decodeIfPresent(String.self, forKey: .releaseDate) ?? c.decodeIfPresent(String.self, forKey: .firstAirDate)
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id); try c.encode(kind, forKey: .kind); try c.encode(title, forKey: .title)
        try c.encode(overview, forKey: .overview); try c.encodeIfPresent(posterPath, forKey: .posterPath)
        try c.encodeIfPresent(backdropPath, forKey: .backdropPath); try c.encode(voteAverage, forKey: .voteAverage)
        try c.encodeIfPresent(releaseDate, forKey: .releaseDate)
    }
}

public struct MediaPage: Codable, Sendable {
    public let page: Int
    public let totalPages: Int
    public let results: [MediaTitle]
    enum CodingKeys: String, CodingKey { case page, results; case totalPages = "total_pages" }
    public init(page: Int = 1, totalPages: Int = 1, results: [MediaTitle]) { self.page = page; self.totalPages = totalPages; self.results = results }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        page = try c.decodeIfPresent(Int.self, forKey: .page) ?? 1
        totalPages = try c.decodeIfPresent(Int.self, forKey: .totalPages) ?? 1
        results = try c.decode([SearchResult].self, forKey: .results).compactMap(\.title)
    }
    private struct SearchResult: Decodable {
        let title: MediaTitle?
        enum CodingKeys: String, CodingKey { case mediaType = "media_type" }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let type = try c.decodeIfPresent(String.self, forKey: .mediaType)
            title = type == "person" ? nil : try MediaTitle(from: decoder)
        }
    }
}
public struct Genre: Codable, Hashable, Identifiable, Sendable {
    public let id: Int
    public let name: String
}
public struct CastMember: Codable, Hashable, Identifiable, Sendable {
    public let id: Int
    public let name: String
    public let character: String?
    public let profilePath: String?
    public var imageURL: URL? { MediaTitle.imageURL(profilePath, size: "w185") }
    enum CodingKeys: String, CodingKey { case id, name, character; case profilePath = "profile_path" }
}
public struct SeasonSummary: Codable, Hashable, Identifiable, Sendable {
    public let id: Int
    public let name: String
    public let seasonNumber: Int
    public let episodeCount: Int
    public let posterPath: String?
    enum CodingKeys: String, CodingKey { case id, name; case seasonNumber = "season_number", episodeCount = "episode_count", posterPath = "poster_path" }
}
public struct Episode: Codable, Hashable, Identifiable, Sendable {
    public let id: Int
    public let name: String
    public let overview: String
    public let seasonNumber: Int
    public let episodeNumber: Int
    public let runtime: Int?
    public let stillPath: String?
    public var imageURL: URL? { MediaTitle.imageURL(stillPath, size: "w300") }
    enum CodingKeys: String, CodingKey { case id, name, overview, runtime; case seasonNumber = "season_number", episodeNumber = "episode_number", stillPath = "still_path" }
    public init(id: Int, name: String, overview: String = "", seasonNumber: Int, episodeNumber: Int, runtime: Int? = nil, stillPath: String? = nil) {
        self.id = id; self.name = name; self.overview = overview; self.seasonNumber = seasonNumber; self.episodeNumber = episodeNumber; self.runtime = runtime; self.stillPath = stillPath
    }
}
public struct SeasonDetails: Codable, Sendable {
    public let id: Int
    public let name: String
    public let episodes: [Episode]
}
public struct Trailer: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let key: String
    public let name: String
    public let site: String
    public let type: String
    public let official: Bool?
    public var url: URL? {
        guard site == "YouTube", key.range(of: "^[a-zA-Z0-9_-]+$", options: .regularExpression) != nil else { return nil }
        return URL(string: "https://www.youtube.com/watch?v=\(key)")
    }
}
public struct TitleDetails: Sendable {
    public let title: MediaTitle
    public let runtime: Int?
    public let genres: [Genre]
    public let cast: [CastMember]
    public let seasons: [SeasonSummary]
    public let trailers: [Trailer]
    public let similar: [MediaTitle]
}
/// TMDB/JustWatch reports title-level availability, never an authorized stream URL.
public struct WatchProvider: Identifiable, Hashable, Sendable {
    public let id: Int
    public let name: String
    public let logoURL: URL?
    public let url: URL
    public let category: String
    public let region: String
    public init(id: Int, name: String, logoURL: URL? = nil, url: URL, category: String, region: String) {
        self.id = id; self.name = name; self.logoURL = logoURL; self.url = url; self.category = category; self.region = region
    }
}
