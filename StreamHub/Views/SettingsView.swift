import SwiftUI
import StreamHubCore

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var updates: UpdateManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("watchRegion") private var region = "US"
    @AppStorage("defaultPlaybackSpeed") private var speed = 1.0
    @AppStorage("resumePlayback") private var resume = true
    @State private var token = ""
    @State private var notice: String?
    @State private var clearHistory = false
    @State private var clearCookies = false
    private let repo = URL(string: "https://github.com/naahs-lawragga/StreamHub-iOS")!
    var body: some View {
        List {
            Section("General") {
                NavigationLink("TMDB connection") { connection }
                Picker("Viewing region", selection: $region) {
                    ForEach(Locale.Region.isoRegions.map(\.identifier).filter { $0.count == 2 }.sorted(), id: \.self) { code in
                        Text(Locale.current.localizedString(forRegionCode: code) ?? code).tag(code)
                    }
                }
            }
            Section("Playback") {
                Toggle("Resume native playback", isOn: $resume)
                Picker("Default speed", selection: $speed) {
                    ForEach([0.5, 0.75, 1, 1.25, 1.5, 2], id: \.self) { value in Text(String(format: "%g×", value)).tag(value) }
                }
                Text("Audio, subtitles, Picture in Picture, and fullscreen controls appear when supported by the stream and system.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Streaming Sources") {
                NavigationLink { SourceManagerView() } label: { Label("Websites & authorized streams", systemImage: "play.rectangle") }
            }
            Section("Browser") {
                NavigationLink { BrowserView(url: BrowserData.shared.lastURL ?? URL(string: "https://www.themoviedb.org")!) } label: { Label("Open browser", systemImage: "safari") }
                Button("Clear browser history", role: .destructive) { BrowserData.shared.clearHistory(); notice = "Browser history cleared." }
                Button("Clear cookies & website data", role: .destructive) { clearCookies = true }
            }
            Section("Appearance") {
                Label("Cinematic dark theme", systemImage: "moon.fill")
                Text("Text follows your system size. Reduce Motion is \(reduceMotion ? "on" : "off"). Refresh rate is managed by iOS.").font(.footnote).foregroundStyle(.secondary)
            }
            Section("Privacy") {
                NavigationLink("Privacy & data") { privacy }
                Button("Clear viewing & search history", role: .destructive) { clearHistory = true }
            }
            Section("Storage") {
                Button("Clear images & metadata cache") {
                    Task {
                        await ImagePipeline.shared.clear()
                        do {
                            try await store.client?.clearCache()
                            await DirectoryClient().clearCache()
                            notice = "Caches cleared. Your watchlist is preserved."
                        } catch { notice = "Some cached metadata could not be cleared. \(error.localizedDescription)" }
                    }
                }
                LabeledContent("Saved titles", value: String(store.snapshot.watchlist.count))
                LabeledContent("Native playback records", value: String(store.snapshot.playback.count))
            }
            Section("Updates") {
                NavigationLink { UpdateSettingsView() } label: {
                    HStack { Label("Updates & installation", systemImage: "arrow.down.circle"); Spacer(); if updates.available != nil { Image(systemName: "circle.fill").foregroundStyle(.red).accessibilityLabel("Update available") } }
                }
            }
            Section("Advanced") {
                NavigationLink("Diagnostics") { diagnostics }
            }
            Section("About") {
                HStack(spacing: 14) {
                    Image("LaunchMark").resizable().frame(width: 52, height: 52).clipShape(RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading) { Text("StreamHub").font(.headline); Text("Version \(updates.installedVersion)").foregroundStyle(.secondary) }
                }
                Link("GitHub repository", destination: repo)
                Link("Report a bug", destination: repo.appendingPathComponent("issues/new/choose"))
                NavigationLink("Credits & open-source licenses") { credits }
                Image("TMDBAttribution").resizable().scaledToFit().frame(width: 90, height: 18).accessibilityLabel("TMDB")
                Text("This product uses the TMDB API but is not endorsed or certified by TMDB.").font(.footnote).foregroundStyle(.secondary)
                Link("Movie & TV metadata by TMDB", destination: URL(string: "https://www.themoviedb.org")!)
            }
        }
        .navigationTitle("Settings").scrollContentBackground(.hidden).background(Color.black)
        .alert("StreamHub", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) { Button("OK") { notice = nil } } message: { Text(notice ?? "") }
        .confirmationDialog("Clear viewing, playback, and search history?", isPresented: $clearHistory, titleVisibility: .visible) { Button("Clear history", role: .destructive) { store.clearHistory() } }
        .confirmationDialog("Clear website data? This signs you out of websites.", isPresented: $clearCookies, titleVisibility: .visible) { Button("Clear website data", role: .destructive) { Task { await BrowserData.shared.clearWebsiteData(); notice = "Website data cleared." } } }
    }
    private var connection: some View {
        Form {
            Section {
                NavigationLink { TMDBTutorialView() } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Set up TMDB step by step").font(.headline)
                            Text("Get your token, complete the form, and connect.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    } icon: { Image(systemName: "book.pages.fill") }
                }
            }
            Section {
                Label(store.tokenConfigured ? "Token saved in Keychain" : "Connect TMDB to discover titles", systemImage: store.tokenConfigured ? "checkmark.shield" : "key")
                SecureField("TMDB API Read Access Token", text: $token).textInputAutocapitalization(.never).autocorrectionDisabled()
                Button("Save token") { store.setToken(token); token = ""; if store.storageError == nil { notice = "TMDB connection updated." } }.disabled(token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if store.tokenConfigured { Button("Remove saved token", role: .destructive) { store.setToken("") } }
            } footer: { Text("Use the API Read Access Token from your TMDB account. It stays in this device’s Keychain and is only sent to api.themoviedb.org. Do not paste it into GitHub.") }
            Link("Get a TMDB API token", destination: URL(string: "https://www.themoviedb.org/settings/api")!)
        }.navigationTitle("TMDB connection")
    }
    private var privacy: some View {
        List {
            Text("StreamHub has no advertising SDK, analytics SDK, or account system. Your watchlist, search history, and native playback progress are stored on this device.")
            Text("TMDB receives metadata searches. Enabled FMHY directory requests go to GitHub. Websites opened in the browser apply their own privacy policies and store cookies. Clearing website data signs you out.")
            Text("Update checks contact the configured HTTPS source while the app is active, at most every six hours unless you request a check. StreamHub never asks for your Apple Account password.")
            Text("Native stream URLs may contain access tokens. They are stored locally to support resume. Clear playback history to remove saved URLs.")
        }.navigationTitle("Privacy")
    }
    private var diagnostics: some View {
        List {
            LabeledContent("App", value: updates.installedVersion)
            LabeledContent("System", value: UIDevice.current.systemVersion)
            LabeledContent("TMDB", value: store.tokenConfigured ? "Configured" : "Not configured")
            LabeledContent("Update source", value: updates.sourceURL == nil ? "Not configured" : "Configured")
            Text("SideStore, LiveContainer multitasking, Picture in Picture, and ProMotion performance require testing on your device. No compatibility or frame-rate guarantee has been established.")
        }.navigationTitle("Diagnostics")
    }
    private var credits: some View {
        List {
            Text("Original StreamHub code and branding: MIT License. Copyright © 2026 StreamHub contributors.")
            Link("Read the MIT license", destination: repo.appendingPathComponent("blob/main/LICENSE"))
            Text("TMDB metadata and artwork remain subject to TMDB and their respective owners’ terms. Viewing provider information is supplied through TMDB by JustWatch; availability depends on region and may change.")
            Link("JustWatch", destination: URL(string: "https://www.justwatch.com")!)
            Text("FMHY is an optional external directory. Its authors retain rights in their directory content; StreamHub does not relicense it under MIT.")
            Link("FMHY contributors", destination: URL(string: "https://fmhy.net")!)
        }.navigationTitle("Credits")
    }
}
