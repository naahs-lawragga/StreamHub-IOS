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
    @AppStorage("watchRegion") private var region = Locale.current.region?.identifier ?? "US"
    @State private var result = ProviderResult(options: [], errors: [])
    @State private var loading = true
    @State private var browserDestination: BrowserDestination?
    @State private var playbackDestination: BrowserDestination?
    @State private var refreshID = UUID()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(title.displayTitle).font(.title2.bold())
                        if let episode { Text("S\(episode.seasonNumber) · E\(episode.episodeNumber) — \(episode.name)").font(.subheadline) }
                        Text("Choose a viewing option").foregroundStyle(.secondary)
                    }.padding(.vertical, 8)
                }
                Section {
                    TextField("Country code (US, GB…)", text: $region)
                        .textInputAutocapitalization(.characters).autocorrectionDisabled()
                        .onSubmit { region = String(region.uppercased().prefix(2)); refreshID = UUID() }
                    if loading { ProgressView("Checking providers…") }
                    ForEach(result.options) { option in
                        Button { browserDestination = BrowserDestination(url: option.url) } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Label(option.name, systemImage: "checkmark.seal")
                                Text(option.detail).font(.caption).foregroundStyle(.secondary)
                                Text(option.evidence.rawValue).font(.caption2).foregroundStyle(.secondary)
                            }.padding(.vertical, 3)
                        }
                    }
                    if !loading && result.options.isEmpty {
                        Text("No verified options were returned for this region.").foregroundStyle(.secondary)
                    }
                    ForEach(result.errors, id: \.self) { Text($0).font(.callout).foregroundStyle(.secondary) }
                    Button("Check again") { refreshID = UUID() }.disabled(loading)
                } header: { Text("Viewing guide") } footer: {
                    Text("Availability data by TMDB and JustWatch. Options open TMDB’s guide; subscription, rental, and geographic restrictions may apply. Data can change. \(episode == nil ? "" : "Availability is for the show, not verified for this episode.")")
                }
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
                    NavigationLink("Manage sources") { SourceManagerView() }
                } header: { Text("Your authorized streams") } footer: {
                    Text("Selecting a stream associates native progress with this title. StreamHub cannot verify the title of a custom URL.")
                }
                if !browser.bookmarks.isEmpty {
                    Section("Unverified websites · Browser only") {
                        ForEach(browser.bookmarks) { bookmark in
                            Button { browserDestination = BrowserDestination(url: bookmark.url) } label: {
                                Label(bookmark.title, systemImage: "globe")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Watch Now").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .task(id: refreshID) { await load() }
            .sheet(item: $browserDestination) { BrowserView(url: $0.url) }
            .fullScreenCover(item: $playbackDestination) {
                NativePlayerView(title: title, url: $0.url, episode: episode).environmentObject(store)
            }
        }.preferredColorScheme(.dark).tint(.red)
    }

    @MainActor private func load() async {
        loading = true
        guard let client = store.client else {
            result = ProviderResult(options: [], errors: ["Configure TMDB in Settings to check viewing options."])
            loading = false; return
        }
        let updated = await ProviderRegistry(providers: [TMDBViewingProvider(client: client)])
            .options(for: ViewingRequest(title: title, episode: episode, region: region.uppercased()))
        guard !Task.isCancelled else { return }
        result = updated; loading = false
    }
}

typealias WatchOptionsView = ProviderPicker
