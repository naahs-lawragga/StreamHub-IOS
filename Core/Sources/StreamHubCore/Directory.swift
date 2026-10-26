import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// FMHY publishes a Markdown wiki, not a title-availability API.
public struct DirectoryEntry: Codable, Identifiable, Hashable, Sendable {
    public var id: String { url.absoluteString }
    public let name: String
    public let url: URL
    public let category: String
}
public enum DirectoryParser {
    public static func parse(_ markdown: String) -> [DirectoryEntry] {
        guard let regex = try? NSRegularExpression(pattern: #"\[([^\]]+)\]\((https://[^\s)]+)\)"#) else { return [] }
        var category = "Websites", entries: [DirectoryEntry] = [], seen = Set<String>()
        for line in markdown.components(separatedBy: .newlines) {
            if line.hasPrefix("#") {
                category = line.trimmingCharacters(in: CharacterSet(charactersIn: "# ►▷ "))
            }
            guard line.hasPrefix("* "), !line.hasPrefix("* **Note**"),
                  let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
                  let nameRange = Range(match.range(at: 1), in: line),
                  let urlRange = Range(match.range(at: 2), in: line),
                  let url = URL(string: String(line[urlRange])), url.host != nil,
                  url.user == nil, url.password == nil, seen.insert(url.absoluteString).inserted else { continue }
            entries.append(DirectoryEntry(name: String(line[nameRange]), url: url, category: category))
        }
        return entries
    }
}
public struct DirectoryResult: Sendable {
    public let entries: [DirectoryEntry]
    public let isOffline: Bool
    public let fetchedAt: Date
}
public actor DirectoryClient {
    public static let sourceURL = URL(string: "https://raw.githubusercontent.com/wiki/fmhy/FMHY/Streaming.md")!
    private struct Cache: Codable { let entries: [DirectoryEntry]; let fetchedAt: Date }
    private let fileURL: URL
    private let session: URLSession
    public init(fileURL: URL? = nil, session: URLSession = .shared) {
        self.fileURL = fileURL ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("StreamHub/fmhy.json")
        self.session = session
    }
    public func fetch(force: Bool = false) async throws -> DirectoryResult {
        let cached = (try? Data(contentsOf: fileURL)).flatMap { try? JSONDecoder().decode(Cache.self, from: $0) }
        if let cached, !force, Date().timeIntervalSince(cached.fetchedAt) < 86400 {
            return DirectoryResult(entries: cached.entries, isOffline: false, fetchedAt: cached.fetchedAt)
        }
        do {
            let (data, response) = try await session.data(for: URLRequest(url: Self.sourceURL, timeoutInterval: 20))
            guard let http = response as? HTTPURLResponse, http.statusCode == 200, data.count < 4_000_000,
                  let markdown = String(data: data, encoding: .utf8) else { throw URLError(.badServerResponse) }
            let entries = DirectoryParser.parse(markdown)
            guard !entries.isEmpty else { throw URLError(.cannotParseResponse) }
            let cache = Cache(entries: entries, fetchedAt: Date())
            try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? JSONEncoder().encode(cache).write(to: fileURL, options: .atomic)
            return DirectoryResult(entries: entries, isOffline: false, fetchedAt: cache.fetchedAt)
        } catch {
            if error is CancellationError || (error as? URLError)?.code == .cancelled { throw error }
            if let cached { return DirectoryResult(entries: cached.entries, isOffline: true, fetchedAt: cached.fetchedAt) }
            throw error
        }
    }
    public func clearCache() { try? FileManager.default.removeItem(at: fileURL) }
}
