import Foundation
import Combine
import StreamHubCore

/// One shared directory for Discover and Watch Now. Entries are browser destinations,
/// never a claim that the selected movie or episode can be watched there.
@MainActor
final class DirectoryStore: ObservableObject {
    static let shared = DirectoryStore()
    @Published private(set) var entries: [DirectoryEntry] = []
    @Published private(set) var isLoading = false
    @Published private(set) var message: String?
    @Published private(set) var favorites: Set<String>
    private let client: DirectoryClient
    private let defaults: UserDefaults

    init(client: DirectoryClient = DirectoryClient(), defaults: UserDefaults = .standard) {
        self.client = client
        self.defaults = defaults
        favorites = defaults.data(forKey: "directoryFavorites")
            .flatMap { try? JSONDecoder().decode(Set<String>.self, from: $0) } ?? []
    }

    func isFavorite(_ entry: DirectoryEntry) -> Bool { favorites.contains(entry.id) }

    func toggleFavorite(_ entry: DirectoryEntry) {
        if favorites.contains(entry.id) { favorites.remove(entry.id) }
        else { favorites.insert(entry.id) }
        if let data = try? JSONEncoder().encode(favorites) {
            defaults.set(data, forKey: "directoryFavorites")
        }
    }

    /// Call only after the user opts in to FMHY. Existing entries stay visible on
    /// refresh and network failure; DirectoryClient also retains its on-disk cache.
    func refresh(force: Bool = false) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await client.fetch(force: force)
            guard !Task.isCancelled else { return }
            entries = result.entries
            message = result.isOffline
                ? "Directory refresh unavailable — showing the saved directory from \(result.fetchedAt.formatted(date: .abbreviated, time: .omitted))."
                : nil
        } catch is CancellationError {
        } catch let error as URLError where error.code == .cancelled {
        } catch {
            message = entries.isEmpty
                ? "Directory unavailable. Try refreshing, or add your own website in Manage websites."
                : "Could not refresh the directory. Saved websites remain available; try again."
        }
    }
}
