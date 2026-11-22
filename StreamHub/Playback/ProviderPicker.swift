import SwiftUI
import StreamHubCore

struct ProviderPicker: View {
    let title: MediaTitle
    var episode: Episode? = nil
    var onSelectNative: ((URL) -> Void)? = nil
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var sources = AuthorizedSources.shared
    @ObservedObject private var browser = BrowserData.shared
    @ObservedObject private var directory = DirectoryStore.shared
    @AppStorage("watchRegion") private var region = Locale.current.region?.identifier ?? "US"
    @AppStorage("hidePaidRentals") private var hidePaidRentals = false
    @AppStorage("fmhyEnabled") private var directoryEnabled = false
    @State private var result = ProviderResult(options: [], errors: [])
    @State private var loading = true
    @State private var browserDestination: BrowserDestination?
    @State private var playbackDestination: BrowserDestination?
    @State private var refreshID = UUID()

    private var selection: SourceSelection {
        SourceSelection(request: ViewingRequest(title: title, episode: episode, region: region.uppercased()),
            configured: browser.bookmarks,
            configuredFavorites: Set(browser.bookmarks.filter { browser.isFavoriteWebsite($0.id) }.map(\.id)),
            directoryEntries: directory.entries, directoryFavorites: directory.favorites,
            directoryEnabled: directoryEnabled, officialOptions: result.options, hidePaidRentals: hidePaidRentals)
    }

    var body: some View {
        NavigationStack {
            List {
                titleSection
                websitesSection
                nativeSection
                officialSection
            }
            .navigationTitle("Watch Now").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .task(id: refreshID) { await load() }
            .task(id: directoryEnabled) { if directoryEnabled { await directory.refresh() } }
            .sheet(item: $browserDestination) { BrowserView(url: $0.url) }
            .fullScreenCover(item: $playbackDestination) {
                NativePlayerView(title: title, url: $0.url, episode: episode).environmentObject(store)
            }
        }.preferredColorScheme(.dark).tint(.red)
    }

    private var titleSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text(title.displayTitle).font(.title2.bold())
                if let episode {
                    Text("S\(episode.seasonNumber) · E\(episode.episodeNumber) — \(episode.name)").font(.subheadline)
                }
                Text("Choose a website, authorized stream, or official viewing guide.").foregroundStyle(.secondary)
            }.padding(.vertical, 8)
        }
    }

    private var websitesSection: some View {
        Section {
            Text("Browser destinations · Movie and episode availability is unverified.")
                .font(.callout).foregroundStyle(.secondary)
            ForEach(selection.websites) { website in websiteRow(website) }
            if selection.websites.isEmpty {
                Text("No websites saved yet. Add a website below or enable the optional directory.")
                    .foregroundStyle(.secondary)
            }
            NavigationLink { SourceManagerView() } label: {
                Label("Manage websites & favorites", systemImage: "bookmark")
            }
            Toggle("Include FMHY directory", isOn: $directoryEnabled)
            if directoryEnabled { directoryControls }
        } header: { Text("Streaming Websites") } footer: {
            Text("Your configured websites appear first, with favorites at the top. Selecting a website opens the built-in browser; it does not confirm this title is available. Sites may require an account, subscription, Safari, or their own app.")
        }
    }

    private func websiteRow(_ website: StreamingWebsiteOption) -> some View {
        Button { browserDestination = BrowserDestination(url: website.url) } label: {
            VStack(alignment: .leading, spacing: 5) {
                Label(website.name, systemImage: website.isFavorite ? "star.fill" : "globe")
                Text("\(website.isConfigured ? "Your website" : "FMHY directory") · Browser only")
                    .font(.caption).foregroundStyle(.secondary)
                Text(website.url.host ?? "Website").font(.caption2).foregroundStyle(.secondary)
            }.padding(.vertical, 3)
        }
    }

    @ViewBuilder private var directoryControls: some View {
        if directory.isLoading { ProgressView("Loading website directory…") }
        if let message = directory.message { Text(message).font(.callout).foregroundStyle(.secondary) }
        if directory.entries.isEmpty && !directory.isLoading {
            Text("The directory has no saved websites. Refresh it or add your own website.")
                .font(.callout).foregroundStyle(.secondary)
        }
        if selection.directoryWebsiteCount > 12 {
            Text("Showing the first 12 directory destinations, with directory favorites first. Browse the full directory below.")
                .font(.caption).foregroundStyle(.secondary)
        }
        NavigationLink { DiscoverView() } label: { Label("Browse FMHY & choose favorites", systemImage: "list.bullet.rectangle") }
        Button("Refresh directory") { Task { await directory.refresh(force: true) } }.disabled(directory.isLoading)
    }

    private var nativeSection: some View {
        Section {
            ForEach(sources.sources) { source in
                Button {
                    if let onSelectNative { onSelectNative(source.url); dismiss() }
                    else { playbackDestination = BrowserDestination(url: source.url) }
                } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        Label(source.name, systemImage: "play.rectangle")
                        Text("Native playback · You verify the title and permission").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            if sources.sources.isEmpty { Text("Add a permitted HLS or MP4 URL in Streaming Sources.").foregroundStyle(.secondary) }
            NavigationLink("Manage authorized streams") { SourceManagerView() }
        } header: { Text("Your authorized streams") } footer: {
            Text("Selecting a stream associates native progress with this title. StreamHub cannot verify the title of a custom URL.")
        }
    }

    private var officialSection: some View {
        Section {
            TextField("Country code (US, GB…)", text: $region)
                .textInputAutocapitalization(.characters).autocorrectionDisabled()
                .onSubmit { region = String(region.uppercased().prefix(2)); refreshID = UUID() }
            Toggle("Hide paid rentals & purchases", isOn: $hidePaidRentals)
            if loading { ProgressView("Checking official providers…") }
            ForEach(selection.officialOptions) { option in
                Button { browserDestination = BrowserDestination(url: option.url) } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        Label(option.name, systemImage: "building.2")
                        Text(option.detail).font(.caption).foregroundStyle(.secondary)
                        Text(option.evidence.rawValue).font(.caption2).foregroundStyle(.secondary)
                    }.padding(.vertical, 3)
                }
            }
            if !loading && selection.officialOptions.isEmpty {
                Text(hidePaidRentals && !result.options.isEmpty ? "No official options remain with rentals and purchases hidden." : "No official provider options were returned for this region.")
                    .foregroundStyle(.secondary)
            }
            ForEach(result.errors, id: \.self) { Text($0).font(.callout).foregroundStyle(.secondary) }
            Button("Check official providers again") { refreshID = UUID() }.disabled(loading)
        } header: { Text("Official Watch Providers") } footer: {
            Text("Availability data by TMDB and JustWatch. Options open TMDB’s guide; subscription, rental, and geographic restrictions may apply. Data can change. \(episode == nil ? "" : "Availability is for the show, not verified for this episode.")")
        }
    }

    @MainActor private func load() async {
        loading = true
        guard let client = store.client else {
            result = ProviderResult(options: [], errors: ["Configure TMDB in Settings to check official providers. Your website destinations are available above."])
            loading = false; return
        }
        let updated = await ProviderRegistry(providers: [TMDBViewingProvider(client: client)])
            .options(for: ViewingRequest(title: title, episode: episode, region: region.uppercased()))
        guard !Task.isCancelled else { return }
        result = updated; loading = false
    }
}

typealias WatchOptionsView = ProviderPicker
