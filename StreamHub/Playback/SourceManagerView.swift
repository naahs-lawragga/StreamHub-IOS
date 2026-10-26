import SwiftUI
import Combine

struct AuthorizedSource: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var url: URL
}

@MainActor
final class AuthorizedSources: ObservableObject {
    static let shared = AuthorizedSources()
    @Published private(set) var sources: [AuthorizedSource] = []
    init() {
        if let data = UserDefaults.standard.data(forKey: "playback.authorizedSources") {
            sources = (try? JSONDecoder().decode([AuthorizedSource].self, from: data)) ?? []
        }
    }
    func add(name: String, url: URL) {
        sources.append(AuthorizedSource(name: name, url: url)); save()
    }
    func remove(at offsets: IndexSet) { sources.remove(atOffsets: offsets); save() }
    private func save() {
        if let data = try? JSONEncoder().encode(sources) {
            UserDefaults.standard.set(data, forKey: "playback.authorizedSources")
        }
    }
}

struct SourceManagerView: View {
    @ObservedObject private var sources = AuthorizedSources.shared
    @ObservedObject private var browser = BrowserData.shared
    @State private var streamName = ""
    @State private var streamAddress = ""
    @State private var authorized = false
    @State private var websiteName = ""
    @State private var websiteAddress = ""
    @State private var browserURL: BrowserDestination?
    @State private var error: String?

    var body: some View {
        Form {
            Section {
                Text("Add streams you own or have permission to play. StreamHub never extracts website video, unlocks subscriptions, or bypasses DRM.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Section("Native playback sources") {
                ForEach(sources.sources) { source in
                    VStack(alignment: .leading) {
                        Text(source.name)
                        Text(source.url.host ?? "HTTPS stream").font(.caption).foregroundStyle(.secondary)
                    }
                }.onDelete(perform: sources.remove)
                TextField("Source name", text: $streamName)
                TextField("Authorized HTTPS HLS or MP4 URL", text: $streamAddress)
                    .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                Toggle("I have permission to play this stream", isOn: $authorized)
                Button("Add native source") { addStream() }
                    .disabled(!authorized || streamName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            Section {
                ForEach(browser.bookmarks) { bookmark in
                    Button { browserURL = BrowserDestination(url: bookmark.url) } label: {
                        VStack(alignment: .leading) {
                            Text(bookmark.title)
                            Text("Unverified website · \(bookmark.url.host ?? "")").font(.caption).foregroundStyle(.secondary)
                        }
                    }.swipeActions { Button("Delete", role: .destructive) { browser.removeBookmark(bookmark.id) } }
                }
                TextField("Website name", text: $websiteName)
                TextField("https://example.com", text: $websiteAddress)
                    .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                Button("Add website bookmark") { addWebsite() }
                    .disabled(websiteName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } header: { Text("Favorite websites") } footer: {
                Text("Bookmarks do not verify title availability. Some sites require Safari, their own app, authentication, or a subscription.")
            }
        }
        .navigationTitle("Streaming Sources")
        .sheet(item: $browserURL) { BrowserView(url: $0.url) }
        .alert("Could not add source", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK") { error = nil }
        } message: { Text(error ?? "") }
    }

    private func addStream() {
        guard let url = AuthorizedStreamPolicy.validate(streamAddress) else {
            error = "Enter a valid HTTPS URL without embedded username or password."; return
        }
        sources.add(name: streamName.trimmingCharacters(in: .whitespacesAndNewlines), url: url)
        streamName = ""; streamAddress = ""; authorized = false
    }
    private func addWebsite() {
        guard let url = WebAddress.parse(websiteAddress) else {
            error = "Enter a valid website address."; return
        }
        if !browser.bookmarks.contains(where: { $0.url == url }) {
            browser.toggleBookmark(title: websiteName.trimmingCharacters(in: .whitespacesAndNewlines), url: url)
        }
        websiteName = ""; websiteAddress = ""
    }
}

struct BrowserDestination: Identifiable {
    let id = UUID()
    let url: URL
}
