import SwiftUI
import StreamHubCore

private struct HomeSection: Identifiable {
    let id: String
    let titles: [MediaTitle]
}

struct HomeView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sections: [HomeSection] = []
    @State private var recommendations: [MediaTitle] = []
    @State private var loading = false
    @State private var error: String?
    @State private var watchTitle: MediaTitle?
    @State private var loadGeneration = UUID()

    private var featured: MediaTitle? { sections.first?.titles.first }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 30) {
                if !store.tokenConfigured {
                    ConfigureMetadataView().frame(minHeight: 380)
                } else if loading && sections.isEmpty {
                    LoadingRows()
                } else {
                    if let featured { hero(featured) }
                    if let error { RetryBanner(message: error) { Task { await load() } }.padding(.horizontal, 20) }
                    ForEach(sections) { section in MediaRow(heading: section.id, titles: section.titles) }
                    if !loading && error == nil && sections.allSatisfy({ $0.titles.isEmpty }) {
                        ContentUnavailableView("No titles yet", systemImage: "film", description: Text("Pull to refresh and try again."))
                    }
                    continueWatching
                    MediaRow(heading: "Recommended for You", titles: recommendations)
                    if recommendations.isEmpty && !sections.isEmpty {
                        Label("Add a title to your watchlist to shape your recommendations.", systemImage: "sparkles")
                            .font(.subheadline).foregroundStyle(.secondary).padding(.horizontal, 20)
                    }
                    MediaRow(heading: "Recently Viewed", titles: store.snapshot.recentlyViewed)
                }
            }.padding(.bottom, 24)
        }
        .background(Brand.background)
        .navigationTitle("STREAMHUB")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { store.selectedTab = 1 } label: { Image(systemName: "magnifyingglass") }
                    .accessibilityLabel("Search titles")
            }
        }
        .refreshable { await load(forceRefresh: true) }
        .task(id: store.connectionRevision) { await load() }
        .task(id: store.snapshot.watchlist.first?.key) { await loadRecommendations() }
        .sheet(item: $watchTitle) { title in ProviderPicker(title: title) }
    }

    private func hero(_ title: MediaTitle) -> some View {
        ZStack(alignment: .bottomLeading) {
            CachedImage(url: title.backdropURL ?? title.posterURL).frame(height: 470)
            LinearGradient(colors: [.clear, .black.opacity(0.25), Brand.background], startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 15) {
                Label("IN THE SPOTLIGHT", systemImage: "sparkles")
                    .font(.caption.weight(.bold)).tracking(2).foregroundStyle(Brand.red)
                Text(title.displayTitle).font(.system(.largeTitle, design: .rounded, weight: .heavy))
                    .lineLimit(3)
                HStack(spacing: 12) {
                    Text(title.year)
                    Text(title.kind == .movie ? "MOVIE" : "TV SERIES")
                    Label(title.voteAverage.formatted(.number.precision(.fractionLength(1))), systemImage: "star.fill")
                }.font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.8))
                Text(title.overview).font(.subheadline).lineLimit(3).foregroundStyle(.white.opacity(0.86))
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { heroButtons(title) }
                    VStack(alignment: .leading, spacing: 12) { heroButtons(title) }
                }
            }.padding(22).padding(.top, 100)
        }
    }

    @ViewBuilder private func heroButtons(_ title: MediaTitle) -> some View {
        Button { watchTitle = title } label: { Label("Watch Now", systemImage: "play.fill").font(.headline).padding(.vertical, 7) }
            .buttonStyle(.borderedProminent).tint(Brand.red)
        NavigationLink { DetailView(title: title) } label: {
            Label("Details", systemImage: "info.circle").font(.headline).padding(.vertical, 7)
        }.buttonStyle(.bordered).tint(.white)
    }

    @ViewBuilder private var continueWatching: some View {
        let records = store.snapshot.playback.filter { $0.position > 0 && !$0.isFinished }
        if !records.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                Text("Continue Watching").font(.title3.bold()).padding(.horizontal, 20)
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 14) {
                        ForEach(records) { record in
                            NavigationLink {
                                NativePlayerView(title: record.title, url: record.streamURL, episode: record.episode)
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    CachedImage(url: record.title.backdropURL).frame(width: 230, height: 130)
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                        .overlay(Image(systemName: "play.circle.fill").font(.largeTitle).foregroundStyle(.white))
                                    ProgressView(value: min(record.position / max(record.duration, 1), 1)).tint(Brand.red)
                                    Text(record.title.displayTitle).font(.subheadline.bold()).lineLimit(1).foregroundStyle(.white)
                                    Text("Resume native playback").font(.caption).foregroundStyle(.secondary)
                                }.frame(width: 230)
                            }.buttonStyle(.plain)
                        }
                    }.padding(.horizontal, 20)
                }.scrollIndicators(.hidden)
            }
        }
    }

    private func load(forceRefresh: Bool = false) async {
        let generation = UUID()
        loadGeneration = generation
        guard let client = store.client else { sections = []; recommendations = []; return }
        loading = true; error = nil
        defer { if loadGeneration == generation { loading = false } }
        let feeds: [(String, TMDBFeed)] = [("Trending Today", .trendingMovies), ("Trending Television", .trendingTV),
                                        ("Popular Movies", .popularMovies), ("Popular TV Shows", .popularTV),
                                        ("New Releases", .newReleases), ("Top Rated", .topRated)]
        // Six metadata requests are bounded; each row can succeed independently.
        let result = await withTaskGroup(of: (Int, [MediaTitle]?, String?).self) { group in
            for (index, feed) in feeds.enumerated() {
                group.addTask {
                    do { return (index, try await client.titles(feed.1, forceRefresh: forceRefresh).results, nil) }
                    catch is CancellationError { return (index, nil, nil) }
                    catch { return (index, nil, error.localizedDescription) }
                }
            }
            var result: [(Int, [MediaTitle]?, String?)] = []
            for await value in group { result.append(value) }
            return result.sorted { $0.0 < $1.0 }
        }
        guard !Task.isCancelled, loadGeneration == generation else { return }
        let loaded = result.compactMap { value -> HomeSection? in
            guard let titles = value.1 else { return sections.first { $0.id == feeds[value.0].0 } }
            return HomeSection(id: feeds[value.0].0, titles: titles)
        }
        if reduceMotion { sections = loaded } else { withAnimation(.easeOut(duration: 0.2)) { sections = loaded } }
        error = result.compactMap(\.2).first
        await loadRecommendations()
    }

    private func loadRecommendations() async {
        guard let client = store.client, let seed = store.snapshot.watchlist.first ?? store.snapshot.recentlyViewed.first else {
            recommendations = []; return
        }
        do { recommendations = try await client.recommendations(for: seed).results }
        catch { recommendations = [] }
    }
}
