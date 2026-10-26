import SwiftUI
import StreamHubCore

private struct WatchRequest: Identifiable {
    let id = UUID()
    let title: MediaTitle
    var episode: Episode?
}
private struct TrailerDestination: Identifiable {
    let id = UUID()
    let url: URL
}

struct DetailView: View {
    let title: MediaTitle
    @EnvironmentObject private var store: AppStore
    @State private var details: TitleDetails?
    @State private var loading = true
    @State private var error: String?
    @State private var selectedSeason = -1
    @State private var episodes: [Episode] = []
    @State private var seasonLoading = false
    @State private var seasonError: String?
    @State private var watchRequest: WatchRequest?
    @State private var trailer: TrailerDestination?

    private var displayTitle: MediaTitle { details?.title ?? title }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 26) {
                artwork
                titleInformation.padding(.horizontal, 20)
                if let error { RetryBanner(message: error) { Task { await load() } }.padding(.horizontal, 20) }
                if loading { ProgressView("Loading details…").frame(maxWidth: .infinity).padding() }
                if let details {
                    if !details.trailers.isEmpty { trailers(details.trailers) }
                    if title.kind == .tv { seasonSection(details.seasons).padding(.horizontal, 20) }
                    if !details.cast.isEmpty { castSection(details.cast) }
                    MediaRow(heading: "More Like This", titles: details.similar)
                }
            }.padding(.bottom, 30)
        }
        .background(Brand.background)
        .navigationTitle(displayTitle.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { store.toggleWatchlist(displayTitle) } label: {
                    Image(systemName: store.isWatchlisted(title) ? "bookmark.fill" : "bookmark")
                }.accessibilityLabel(store.isWatchlisted(title) ? "Remove from watchlist" : "Add to watchlist")
            }
        }
        .task(id: title.key) {
            store.recordViewed(title)
            selectedSeason = store.snapshot.selectedSeasons[title.key] ?? -1
            await load()
        }
        .task(id: selectedSeason) { await loadSeason() }
        .onChange(of: selectedSeason) { _, number in
            guard number >= 0 else { return }
            store.snapshot.selectedSeasons[title.key] = number
            store.persist()
        }
        .sheet(item: $watchRequest) { request in ProviderPicker(title: request.title, episode: request.episode) }
        .sheet(item: $trailer) { destination in BrowserView(url: destination.url) }
    }

    private var artwork: some View {
        ZStack(alignment: .bottomLeading) {
            CachedImage(url: displayTitle.backdropURL ?? displayTitle.posterURL).frame(height: 275)
            LinearGradient(colors: [.clear, Brand.background], startPoint: .top, endPoint: .bottom)
            CachedImage(url: displayTitle.posterURL).frame(width: 104, height: 156)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.15), lineWidth: 1))
                .shadow(color: .black.opacity(0.5), radius: 18, y: 8)
                .padding(.horizontal, 20)
        }
    }

    private var titleInformation: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(displayTitle.displayTitle).font(.largeTitle.bold()).fixedSize(horizontal: false, vertical: true)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 14) { facts }
                VStack(alignment: .leading, spacing: 8) { facts }
            }.font(.subheadline).foregroundStyle(.secondary)
            if let genres = details?.genres, !genres.isEmpty {
                Text(genres.map(\.name).joined(separator: "  ·  ")).font(.subheadline.weight(.medium)).foregroundStyle(.white.opacity(0.9))
            }
            Text(displayTitle.overview.isEmpty ? "A synopsis is not available for this title yet." : displayTitle.overview)
                .font(.body).foregroundStyle(.white.opacity(0.85)).lineSpacing(5)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { actionButtons }
                VStack(alignment: .leading, spacing: 12) { actionButtons }
            }
        }
    }

    @ViewBuilder private var facts: some View {
        if !displayTitle.year.isEmpty { Text(displayTitle.year) }
        Text(displayTitle.kind == .movie ? "Movie" : "TV Series")
        if let runtime = details?.runtime, runtime > 0 { Text("\(runtime) min") }
        if displayTitle.voteAverage > 0 {
            Label("\(displayTitle.voteAverage.formatted(.number.precision(.fractionLength(1)))) / 10", systemImage: "star.fill")
                .foregroundStyle(.yellow)
        }
    }

    @ViewBuilder private var actionButtons: some View {
        Button { watchRequest = WatchRequest(title: displayTitle) } label: {
            Label("Watch Now", systemImage: "play.fill").font(.headline).padding(.vertical, 7)
        }.buttonStyle(.borderedProminent)
        Button { store.toggleWatchlist(displayTitle) } label: {
            Label(store.isWatchlisted(title) ? "Saved" : "Watchlist", systemImage: store.isWatchlisted(title) ? "checkmark" : "plus")
                .font(.headline).padding(.vertical, 7)
        }.buttonStyle(.bordered).tint(.white)
    }

    private func trailers(_ trailers: [Trailer]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Trailers & Extras").font(.title3.bold()).padding(.horizontal, 20)
            ScrollView(.horizontal) {
                LazyHStack(spacing: 12) {
                    ForEach(trailers.filter { $0.url != nil }) { item in
                        Button {
                            if let url = item.url { trailer = TrailerDestination(url: url) }
                        } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                Image(systemName: "play.rectangle.fill").font(.title).foregroundStyle(Brand.red)
                                Text(item.name).font(.subheadline.bold()).lineLimit(2).foregroundStyle(.white)
                                Text(item.site).font(.caption).foregroundStyle(.secondary)
                            }.frame(width: 190, alignment: .leading).padding(16)
                                .background(Brand.surface, in: RoundedRectangle(cornerRadius: 16))
                        }.buttonStyle(.plain)
                    }
                }.padding(.horizontal, 20)
            }.scrollIndicators(.hidden)
        }
    }

    private func castSection(_ cast: [CastMember]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("The Cast").font(.title3.bold()).padding(.horizontal, 20)
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 16) {
                    ForEach(cast) { person in
                        VStack(alignment: .leading, spacing: 8) {
                            CachedImage(url: person.imageURL).frame(width: 90, height: 90).clipShape(Circle())
                            Text(person.name).font(.caption.bold()).foregroundStyle(.white)
                            if let character = person.character { Text(character).font(.caption2).foregroundStyle(.secondary).lineLimit(2) }
                        }.frame(width: 96, alignment: .leading).accessibilityElement(children: .combine)
                    }
                }.padding(.horizontal, 20)
            }.scrollIndicators(.hidden)
        }
    }

    private func seasonSection(_ seasons: [SeasonSummary]) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Episodes").font(.title3.bold())
                Spacer()
                Picker("Season", selection: $selectedSeason) {
                    ForEach(seasons) { season in Text(season.name).tag(season.seasonNumber) }
                }.pickerStyle(.menu)
            }
            if seasonLoading { ProgressView("Loading episodes…").frame(maxWidth: .infinity).padding() }
            if let seasonError { RetryBanner(message: seasonError) { Task { await loadSeason() } } }
            if !seasonLoading && episodes.isEmpty && seasonError == nil {
                Text("Episodes have not been announced for this season.").foregroundStyle(.secondary)
            }
            ForEach(episodes) { episode in episodeRow(episode) }
        }
    }

    private func episodeRow(_ episode: Episode) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 14) {
                    episodeImage(episode)
                    episodeHeading(episode)
                }
                VStack(alignment: .leading, spacing: 14) {
                    episodeImage(episode)
                    episodeHeading(episode)
                }
            }
            if !episode.overview.isEmpty { Text(episode.overview).font(.subheadline).foregroundStyle(.secondary).lineLimit(4) }
            Button { watchRequest = WatchRequest(title: displayTitle, episode: episode) } label: {
                Label("Watch Episode", systemImage: "play.fill").font(.subheadline.bold())
            }.buttonStyle(.bordered)
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(Brand.surface, in: RoundedRectangle(cornerRadius: 16))
    }

    private func episodeImage(_ episode: Episode) -> some View {
        CachedImage(url: episode.imageURL).frame(width: 120, height: 72).clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func episodeHeading(_ episode: Episode) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("EPISODE \(episode.episodeNumber)").font(.caption2.bold()).tracking(1).foregroundStyle(Brand.red)
            Text(episode.name).font(.headline).fixedSize(horizontal: false, vertical: true)
            if let runtime = episode.runtime { Text("\(runtime) min").font(.caption).foregroundStyle(.secondary) }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func load() async {
        guard let client = store.client else { loading = false; error = "Connect TMDB in Settings to load complete details."; return }
        loading = true; error = nil
        do {
            let loaded = try await client.details(for: title)
            try Task.checkCancellation()
            details = loaded
            if title.kind == .tv && !loaded.seasons.contains(where: { $0.seasonNumber == selectedSeason }) {
                selectedSeason = loaded.seasons.first(where: { $0.seasonNumber > 0 })?.seasonNumber ?? loaded.seasons.first?.seasonNumber ?? -1
            }
        } catch is CancellationError { }
        catch { self.error = error.localizedDescription }
        loading = false
    }

    private func loadSeason() async {
        guard title.kind == .tv, selectedSeason >= 0, let client = store.client else { return }
        let requestedSeason = selectedSeason
        seasonLoading = true; seasonError = nil; episodes = []
        do {
            let loaded = try await client.season(showID: title.id, number: requestedSeason)
            guard !Task.isCancelled, requestedSeason == selectedSeason else { return }
            episodes = loaded.episodes
        } catch is CancellationError { }
        catch { if requestedSeason == selectedSeason { seasonError = error.localizedDescription } }
        if requestedSeason == selectedSeason { seasonLoading = false }
    }
}
