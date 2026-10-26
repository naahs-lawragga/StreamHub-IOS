import SwiftUI
import StreamHubCore

struct SearchView: View {
    @EnvironmentObject private var store: AppStore
    @SceneStorage("searchQuery") private var query = ""
    @State private var results: [MediaTitle] = []
    @State private var page = 0
    @State private var totalPages = 0
    @State private var loading = false
    @State private var error: String?
    @State private var completedQuery = ""
    @State private var paginationTask: Task<Void, Never>?
    private let columns = [GridItem(.adaptive(minimum: 132), spacing: 16, alignment: .top)]

    var body: some View {
        Group {
            if !store.tokenConfigured { ConfigureMetadataView() }
            else if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { recentSearches }
            else {
                ScrollView {
                    LazyVStack(spacing: 20) {
                        if let error { RetryBanner(message: error) { Task { await search(reset: true) } } }
                        if !results.isEmpty {
                            HStack {
                                Text("Find your next story").font(.title3.bold())
                                Spacer()
                                Text("\(results.count) titles").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 22) {
                            ForEach(results, id: \.key) { title in
                                NavigationLink { DetailView(title: title) } label: { PosterCard(title: title) }
                                    .buttonStyle(.plain)
                            }
                        }
                        if loading { ProgressView("Searching…").padding() }
                        else if results.isEmpty && error == nil && completedQuery == query {
                            ContentUnavailableView.search(text: query)
                        } else if page < totalPages {
                            Button("Load More") { loadMore() }
                                .buttonStyle(.bordered).padding()
                                .onAppear { loadMore() }
                        }
                    }.padding(20)
                }
            }
        }
        .background(Brand.background)
        .navigationTitle("Search")
        .searchable(text: $query, prompt: "Movies, shows, and stories")
        .task(id: query + String(store.connectionRevision)) {
            paginationTask?.cancel()
            results = []; page = 0; totalPages = 0; error = nil; loading = false
            guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { loading = false; return }
            do {
                try await Task.sleep(for: .milliseconds(350))
                try Task.checkCancellation()
                await search(reset: true)
            } catch { }
        }
        .onSubmit(of: .search) { store.recordSearch(query) }
        .onDisappear { paginationTask?.cancel() }
    }

    private var recentSearches: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("What are you in the mood for?").font(.largeTitle.bold()).padding(.top)
                Text("Search the world of movies and television.")
                    .foregroundStyle(.secondary)
                if !store.snapshot.searchHistory.isEmpty {
                    HStack {
                        Text("Recent searches").font(.headline)
                        Spacer()
                        Button("Clear") { store.snapshot.searchHistory = []; store.persist() }.font(.subheadline)
                    }
                    ForEach(store.snapshot.searchHistory, id: \.self) { search in
                        Button { query = search } label: {
                            HStack {
                                Image(systemName: "clock").foregroundStyle(.secondary)
                                Text(search).foregroundStyle(.white)
                                Spacer()
                                Image(systemName: "arrow.up.left").foregroundStyle(.secondary)
                            }.padding(.vertical, 9)
                        }
                    }
                }
            }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func loadMore() {
        guard !loading else { return }
        paginationTask?.cancel()
        paginationTask = Task { await search(reset: false) }
    }

    private func search(reset: Bool) async {
        guard let client = store.client, reset || !loading else { return }
        let requestedQuery = query
        let targetPage = reset ? 1 : page + 1
        guard !requestedQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        loading = true; error = nil
        do {
            let result = try await client.search(requestedQuery, page: targetPage)
            guard !Task.isCancelled, requestedQuery == query else { return }
            if reset { results = result.results }
            else {
                let existing = Set(results.map(\.key))
                results += result.results.filter { !existing.contains($0.key) }
            }
            page = result.page; totalPages = min(result.totalPages, 500)
            completedQuery = requestedQuery
            store.recordSearch(requestedQuery)
        } catch is CancellationError { }
        catch { if requestedQuery == query && !Task.isCancelled { self.error = error.localizedDescription } }
        if requestedQuery == query { loading = false }
    }
}
