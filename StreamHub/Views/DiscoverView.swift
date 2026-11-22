import SwiftUI
import StreamHubCore

struct DiscoverView: View {
    @AppStorage("fmhyEnabled") private var enabled = false
    @ObservedObject private var directory = DirectoryStore.shared
    @State private var query = ""
    @State private var category = "All categories"
    @State private var favoritesOnly = false
    @State private var browser: DirectoryEntry?
    private var filtered: [DirectoryEntry] {
        directory.entries.filter { (category == "All categories" || $0.category == category) && (!favoritesOnly || directory.isFavorite($0)) && (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query)) }
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
                Text("FMHY links are unverified browser destinations. Directory inclusion does not confirm movie or episode availability, authorization, or compatibility. The directory uses FMHY’s published Markdown wiki; its format can change.").font(.footnote).foregroundStyle(.secondary)
            } footer: {
                Link("Directory maintained by FMHY · original source", destination: URL(string: "https://github.com/fmhy/FMHY/wiki/Streaming")!)
            }
            if enabled {
                Section {
                    Picker("Category", selection: $category) {
                        Text("All categories").tag("All categories")
                        ForEach(Array(Set(directory.entries.map(\.category))).sorted(), id: \.self) { Text($0).tag($0) }
                    }
                    Toggle("Favorites only", isOn: $favoritesOnly)
                    if directory.isLoading { ProgressView("Refreshing directory…") }
                    if let message = directory.message { Text(message).foregroundStyle(.secondary) }
                    Button("Refresh directory") { Task { await directory.refresh(force: true) } }.disabled(directory.isLoading)
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
                            Button { directory.toggleFavorite(entry) } label: {
                                Image(systemName: directory.isFavorite(entry) ? "star.fill" : "star")
                            }.buttonStyle(.borderless).accessibilityLabel("Favorite \(entry.name)")
                        }
                    }
                    if filtered.isEmpty && !directory.isLoading { Text("No websites match your filters.").foregroundStyle(.secondary) }
                }
            }
        }
        .navigationTitle("Discover")
        .searchable(text: $query, prompt: "Search websites")
        .scrollContentBackground(.hidden).background(Color.black)
        .task(id: enabled) { if enabled { await directory.refresh() } }
        .refreshable { if enabled { await directory.refresh(force: true) } }
        .sheet(item: $browser) { BrowserView(url: $0.url) }
    }
}
