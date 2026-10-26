import SwiftUI
import Security
import StreamHubCore

@MainActor
final class AppStore: ObservableObject {
    @Published var snapshot = LibrarySnapshot()
    @Published private(set) var client: TMDBClient?
    @Published private(set) var tokenConfigured = false
    @Published private(set) var connectionRevision = 0
    @Published var storageError: String?
    @Published var selectedTab = 0
    @Published var isLoaded = false
    private let library = LibraryStore()
    private var saveTask: Task<Void, Never>?

    init() {
        if let token = KeychainVault.read(), !token.isEmpty {
            client = TMDBClient(token: token)
            tokenConfigured = true
        }
    }

    func load() async {
        guard !isLoaded else { return }
        do {
            snapshot = try await library.load()
            isLoaded = true
        } catch {
            storageError = "Your saved library could not be opened. The original file has been preserved. \(error.localizedDescription)"
        }
    }

    func setToken(_ token: String) {
        let value = token.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try KeychainVault.write(value)
            client = value.isEmpty ? nil : TMDBClient(token: value)
            tokenConfigured = !value.isEmpty
            connectionRevision += 1
            storageError = nil
        } catch { storageError = error.localizedDescription }
    }

    func isWatchlisted(_ title: MediaTitle) -> Bool {
        snapshot.watchlist.contains { $0.key == title.key }
    }

    func toggleWatchlist(_ title: MediaTitle) {
        if isWatchlisted(title) { snapshot.watchlist.removeAll { $0.key == title.key } }
        else { snapshot.watchlist.insert(title, at: 0) }
        persist()
    }

    func recordViewed(_ title: MediaTitle) {
        snapshot.recentlyViewed.removeAll { $0.key == title.key }
        snapshot.recentlyViewed.insert(title, at: 0)
        snapshot.recentlyViewed = Array(snapshot.recentlyViewed.prefix(100))
        persist()
    }

    func recordSearch(_ text: String) {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        snapshot.searchHistory.removeAll { $0.localizedCaseInsensitiveCompare(query) == .orderedSame }
        snapshot.searchHistory.insert(query, at: 0)
        snapshot.searchHistory = Array(snapshot.searchHistory.prefix(30))
        persist()
    }

    func clearHistory() {
        snapshot.recentlyViewed = []
        snapshot.searchHistory = []
        snapshot.playback = []
        persist()
    }

    func persist() {
        guard isLoaded else { return }
        saveTask?.cancel()
        saveTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(200))
                try Task.checkCancellation()
                try await library.save(snapshot)
            } catch is CancellationError { } catch { storageError = error.localizedDescription }
        }
    }

    func flush() async {
        saveTask?.cancel()
        guard isLoaded else { return }
        do { try await library.save(snapshot) }
        catch { storageError = error.localizedDescription }
    }
}

private enum KeychainVault {
    static let service = "app.streamhub.tmdb"
    static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: "read-access-token"]
    }

    static func read() -> String? {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(request as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func write(_ token: String) throws {
        if token.isEmpty { SecItemDelete(query as CFDictionary); return }
        let values: [String: Any] = [kSecValueData as String: Data(token.utf8),
                                   kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        var result = SecItemUpdate(query as CFDictionary, values as CFDictionary)
        if result == errSecItemNotFound {
            result = SecItemAdd(query.merging(values) { _, new in new } as CFDictionary, nil)
        }
        guard result == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(result),
                          userInfo: [NSLocalizedDescriptionKey: "The TMDB token could not be saved securely (\(result))."])
        }
    }
}
