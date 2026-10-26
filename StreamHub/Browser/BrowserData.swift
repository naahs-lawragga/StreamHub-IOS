import Foundation
import WebKit
import Combine

struct BrowserEntry: Codable, Identifiable, Hashable {
    let id: UUID
    var title: String
    var url: URL
    var visitedAt: Date

    init(title: String, url: URL) {
        id = UUID()
        self.title = title
        self.url = url
        visitedAt = Date()
    }
}

/// Browser metadata stays on this device. Cookies are managed by WebKit's persistent store.
@MainActor
final class BrowserData: ObservableObject {
    static let shared = BrowserData()
    @Published private(set) var bookmarks: [BrowserEntry]
    @Published private(set) var history: [BrowserEntry]
    var lastURL: URL? { defaults.string(forKey: "browser.lastURL").flatMap(WebAddress.parse) }
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        bookmarks = Self.read("browser.bookmarks", defaults: defaults)
        history = Self.read("browser.history", defaults: defaults)
    }

    private static func read(_ key: String, defaults: UserDefaults) -> [BrowserEntry] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([BrowserEntry].self, from: data)) ?? []
    }

    func record(title: String, url: URL) {
        guard WebAddress.isWebURL(url) else { return }
        history.removeAll { $0.url == url }
        history.insert(BrowserEntry(title: title, url: url), at: 0)
        history = Array(history.prefix(100))
        save(history, key: "browser.history")
        defaults.set(url.absoluteString, forKey: "browser.lastURL")
    }

    func toggleBookmark(title: String, url: URL) {
        guard WebAddress.isWebURL(url) else { return }
        if bookmarks.contains(where: { $0.url == url }) {
            bookmarks.removeAll { $0.url == url }
        } else {
            bookmarks.insert(BrowserEntry(title: title, url: url), at: 0)
        }
        save(bookmarks, key: "browser.bookmarks")
    }

    func removeBookmark(_ id: UUID) {
        bookmarks.removeAll { $0.id == id }
        save(bookmarks, key: "browser.bookmarks")
    }

    func clearHistory() {
        history.removeAll()
        defaults.removeObject(forKey: "browser.history")
        defaults.removeObject(forKey: "browser.lastURL")
    }

    func clearWebsiteData() async {
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        await WKWebsiteDataStore.default().removeData(ofTypes: types, modifiedSince: .distantPast)
    }

    private func save(_ entries: [BrowserEntry], key: String) {
        if let data = try? JSONEncoder().encode(entries) { defaults.set(data, forKey: key) }
    }
}

enum WebAddress {
    static func isWebURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil else { return false }
        return scheme == "https" || scheme == "http"
    }

    static func parse(_ text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(where: { $0.isWhitespace }) else { return nil }
        if let scheme = URL(string: trimmed)?.scheme {
            guard ["http", "https"].contains(scheme.lowercased()), trimmed.contains("://") else { return nil }
        }
        let candidate = trimmed.contains("://") ? trimmed : "https://" + trimmed
        guard let url = URL(string: candidate), isWebURL(url) else { return nil }
        return url
    }
}
