import SwiftUI
import StreamHubCore

struct DiscoverView: View {
    @AppStorage("fmhyEnabled") private var enabled = false
    @AppStorage("directoryFavorites") private var favoriteData = Data()
    @State private var entries: [DirectoryEntry] = []
    @State private var query = ""
    @State private var category = "All categories"
    @State private var favoritesOnly = false
    @State private var isLoading = false
    @State private var message: String?
    @State private var browser: DirectoryEntry?
    private let client = DirectoryClient()
    private var favorites: Set<String> { (try? JSONDecoder().decode(Set<String>.self, from: favoriteData)) ?? [] }
    private var filtered: [DirectoryEntry] {
        entries.filter { (category == "All categories" || $0.category == category) && (!favoritesOnly || favorites.contains($0.id)) && (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query)) }
    }
    var body: some View {
        List {
            Section {
                Text("Find your next destination.").font(.largeTitle.bold())
                Text("Browse your own websites or explore the optional FMHY directory.").foregroundStyle(.secondary)
                NavigationLink { SourceManagerView() } label: { Label("My websites & streams", systemImage: "bookmark") }
            }
            Section {
                Toggle("Explore FMHY", isOn: $enabled)
                Text("FMHY links are unverified websites. Directory inclusion does not confirm a title is available, that a site is authorized, or that it works in the browser.").font(.footnote).foregroundStyle(.secondary)
            } footer: {
                Link("Directory maintained by FMHY · original source", destination: URL(string: "https://github.com/fmhy/FMHY/wiki/Streaming")!)
            }
            if enabled {
                Section {
                    Picker("Category", selection: $category) {
                        Text("All categories").tag("All categories")
                        ForEach(Array(Set(entries.map(\.category))).sorted(), id: \.self) { Text($0).tag($0) }
                    }
                    Toggle("Favorites only", isOn: $favoritesOnly)
                    if isLoading { ProgressView("Refreshing directory…") }
                    if let message { Text(message).foregroundStyle(.secondary) }
                    Button("Refresh directory") { Task { await refresh(force: true) } }.disabled(isLoading)
                }
                Section("Unverified websites · browser only") {
                    ForEach(filtered) { entry in
                        HStack {
                            Button { browser = entry } label: {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(entry.name).font(.headline).foregroundStyle(.primary)
                                    Text(entry.url.host ?? "Website").font(.caption).foregroundStyle(.secondary)
                                }.frame(maxWidth: .infinity, alignment: .leading)
                            }.buttonStyle(.plain)
                            Button { toggleFavorite(entry) } label: {
                                Image(systemName: favorites.contains(entry.id) ? "star.fill" : "star")
                            }.buttonStyle(.borderless).accessibilityLabel("Favorite \(entry.name)")
                        }
                    }
                    if filtered.isEmpty && !isLoading { Text("No websites match your filters.").foregroundStyle(.secondary) }
                }
            }
        }
        .navigationTitle("Discover")
        .searchable(text: $query, prompt: "Search websites")
        .scrollContentBackground(.hidden).background(Color.black)
        .task(id: enabled) { if enabled { await refresh() } }
        .refreshable { if enabled { await refresh(force: true) } }
        .sheet(item: $browser) { BrowserView(url: $0.url) }
    }
    private func toggleFavorite(_ entry: DirectoryEntry) {
        var values = favorites
        if values.contains(entry.id) { values.remove(entry.id) } else { values.insert(entry.id) }
        favoriteData = (try? JSONEncoder().encode(values)) ?? Data()
    }
    @MainActor private func refresh(force: Bool = false) async {
        isLoading = true; defer { isLoading = false }
        do {
            let result = try await client.fetch(force: force)
            entries = result.entries
            message = result.isOffline ? "Offline — showing the saved directory from \(result.fetchedAt.formatted(date: .abbreviated, time: .omitted))." : nil
        } catch is CancellationError { } catch { message = "Directory unavailable. Check your connection and try refreshing." }
    }
}
