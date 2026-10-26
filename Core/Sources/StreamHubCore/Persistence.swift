import Foundation

public struct WebsiteBookmark: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var url: URL
    public var createdAt: Date
    public init(id: UUID = UUID(), name: String, url: URL, createdAt: Date = Date()) {
        self.id = id; self.name = name; self.url = url; self.createdAt = createdAt
    }
}
public struct BrowserHistoryEntry: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public let title: String
    public let url: URL
    public let visitedAt: Date
    public init(id: UUID = UUID(), title: String, url: URL, visitedAt: Date = Date()) {
        self.id = id; self.title = title; self.url = url; self.visitedAt = visitedAt
    }
}
/// Progress is only recorded for native AVPlayer playback, never inferred from websites.
public struct PlaybackRecord: Codable, Identifiable, Hashable, Sendable {
    public var id: String { title.key + (episode.map { "/\($0.seasonNumber)/\($0.episodeNumber)" } ?? "") }
    public let title: MediaTitle
    public let episode: Episode?
    public let streamURL: URL
    public var position: Double
    public var duration: Double
    public var updatedAt: Date
    public var progress: Double { duration.isFinite && duration > 0 ? min(1, max(0, position / duration)) : 0 }
    public var isFinished: Bool { duration > 0 && progress >= 0.95 }
    public init(title: MediaTitle, episode: Episode? = nil, streamURL: URL, position: Double = 0, duration: Double = 0, updatedAt: Date = Date()) {
        self.title = title; self.episode = episode; self.streamURL = streamURL
        self.position = position.isFinite ? max(0, position) : 0
        self.duration = duration.isFinite ? max(0, duration) : 0
        self.updatedAt = updatedAt
    }
}
public struct LibrarySnapshot: Codable, Sendable {
    public var watchlist: [MediaTitle]
    public var recentlyViewed: [MediaTitle]
    public var bookmarks: [WebsiteBookmark]
    public var playback: [PlaybackRecord]
    public var searchHistory: [String]
    public var browserHistory: [BrowserHistoryEntry]
    public var selectedSeasons: [String: Int]
    public var lastBrowserURL: URL?
    public init(watchlist: [MediaTitle] = [], recentlyViewed: [MediaTitle] = [], bookmarks: [WebsiteBookmark] = [], playback: [PlaybackRecord] = [], searchHistory: [String] = [], browserHistory: [BrowserHistoryEntry] = [], selectedSeasons: [String: Int] = [:], lastBrowserURL: URL? = nil) {
        self.watchlist = watchlist; self.recentlyViewed = recentlyViewed; self.bookmarks = bookmarks
        self.playback = playback; self.searchHistory = searchHistory; self.browserHistory = browserHistory
        self.selectedSeasons = selectedSeasons; self.lastBrowserURL = lastBrowserURL
    }
    enum CodingKeys: String, CodingKey { case watchlist, recentlyViewed, bookmarks, playback, searchHistory, browserHistory, selectedSeasons, lastBrowserURL }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        watchlist = try c.decodeIfPresent([MediaTitle].self, forKey: .watchlist) ?? []
        recentlyViewed = try c.decodeIfPresent([MediaTitle].self, forKey: .recentlyViewed) ?? []
        bookmarks = try c.decodeIfPresent([WebsiteBookmark].self, forKey: .bookmarks) ?? []
        playback = try c.decodeIfPresent([PlaybackRecord].self, forKey: .playback) ?? []
        searchHistory = try c.decodeIfPresent([String].self, forKey: .searchHistory) ?? []
        browserHistory = try c.decodeIfPresent([BrowserHistoryEntry].self, forKey: .browserHistory) ?? []
        selectedSeasons = try c.decodeIfPresent([String: Int].self, forKey: .selectedSeasons) ?? [:]
        lastBrowserURL = try c.decodeIfPresent(URL.self, forKey: .lastBrowserURL)
    }
}

public actor LibraryStore {
    public let fileURL: URL
    public init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultDirectory.appendingPathComponent("library.json")
    }
    public static var defaultDirectory: URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        return root.appendingPathComponent("StreamHub", isDirectory: true)
    }
    public func load() throws -> LibrarySnapshot {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return LibrarySnapshot() }
        return try JSONDecoder().decode(LibrarySnapshot.self, from: Data(contentsOf: fileURL))
    }
    public func save(_ snapshot: LibrarySnapshot) throws {
        var bounded = snapshot
        bounded.recentlyViewed = Array(snapshot.recentlyViewed.prefix(100))
        bounded.searchHistory = Array(snapshot.searchHistory.prefix(30))
        bounded.browserHistory = Array(snapshot.browserHistory.prefix(200))
        bounded.playback = Array(snapshot.playback.sorted { $0.updatedAt > $1.updatedAt }.prefix(500))
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(bounded).write(to: fileURL, options: .atomic)
    }
}
