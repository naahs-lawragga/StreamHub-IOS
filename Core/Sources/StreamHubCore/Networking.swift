import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct HTTPResult: Sendable {
    public let data: Data
    public let statusCode: Int
    public let headers: [String: String]
    public init(data: Data, statusCode: Int, headers: [String: String] = [:]) {
        self.data = data; self.statusCode = statusCode
        self.headers = Dictionary(headers.map { ($0.key.lowercased(), $0.value) }, uniquingKeysWith: { _, last in last })
    }
}
public protocol HTTPTransport: Sendable {
    func data(for request: URLRequest) async throws -> HTTPResult
}
public struct URLSessionTransport: HTTPTransport, @unchecked Sendable {
    private let session: URLSession
    public init(session: URLSession? = nil) {
        if let session { self.session = session } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 20
            configuration.timeoutIntervalForResource = 45
            configuration.urlCache = nil
            self.session = URLSession(configuration: configuration)
        }
    }
    public func data(for request: URLRequest) async throws -> HTTPResult {
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        let headers = response.allHeaderFields.reduce(into: [String: String]()) { result, item in
            if let name = item.key as? String { result[name] = String(describing: item.value) }
        }
        return HTTPResult(data: data, statusCode: response.statusCode, headers: headers)
    }
}
public enum APIError: Error, LocalizedError, Equatable {
    case missingCredential, unauthorized, rateLimited, invalidResponse, server(Int), invalidRequest
    public var errorDescription: String? {
        switch self {
        case .missingCredential: return "Add your TMDB API read access token in Settings to discover movies and shows."
        case .unauthorized: return "TMDB rejected this token. Check your API read access token in Settings."
        case .rateLimited: return "TMDB is receiving too many requests. Try again shortly."
        case .invalidResponse: return "The server returned an unexpected response."
        case .server(let code): return "The service could not complete the request (HTTP \(code))."
        case .invalidRequest: return "This request is not valid."
        }
    }
}

/// A bounded disk cache. Credentials are never part of a key or persisted response.
public actor MetadataCache {
    private struct Entry: Codable { let data: Data; let savedAt: Date }
    private let directory: URL
    private let maximumBytes: Int
    public init(directory: URL? = nil, maximumBytes: Int = 24 * 1024 * 1024) {
        let root = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        self.directory = directory ?? root.appendingPathComponent("StreamHub/Metadata", isDirectory: true)
        self.maximumBytes = maximumBytes
    }
    public func data(for key: String, maximumAge: TimeInterval? = nil) -> Data? {
        guard let data = try? Data(contentsOf: file(for: key)), let entry = try? JSONDecoder().decode(Entry.self, from: data) else { return nil }
        if let maximumAge, Date().timeIntervalSince(entry.savedAt) > maximumAge { return nil }
        return entry.data
    }
    public func put(_ data: Data, for key: String, savedAt: Date = Date()) {
        guard data.count <= maximumBytes / 2 else { return }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try JSONEncoder().encode(Entry(data: data, savedAt: savedAt)).write(to: file(for: key), options: .atomic)
            prune()
        } catch { /* Cache failure must not discard successful network results. */ }
    }
    public func clear() throws {
        if FileManager.default.fileExists(atPath: directory.path) { try FileManager.default.removeItem(at: directory) }
    }
    private func file(for key: String) -> URL {
        // Stable FNV-1a filename; no security or content integrity claims.
        let hash = key.utf8.reduce(UInt64(14695981039346656037)) { ($0 ^ UInt64($1)) &* 1099511628211 }
        return directory.appendingPathComponent(String(hash, radix: 16) + ".json")
    }
    private func prune() {
        let keys: Set<URLResourceKey> = [.fileSizeKey, .contentModificationDateKey]
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: Array(keys)) else { return }
        let records = files.compactMap { url -> (URL, Int, Date)? in
            guard let values = try? url.resourceValues(forKeys: keys) else { return nil }
            return (url, values.fileSize ?? 0, values.contentModificationDate ?? .distantPast)
        }.sorted { $0.2 < $1.2 }
        var bytes = records.reduce(0) { $0 + $1.1 }
        var count = records.count
        for item in records where bytes > maximumBytes || count > 300 {
            try? FileManager.default.removeItem(at: item.0)
            bytes -= item.1; count -= 1
        }
    }
}
