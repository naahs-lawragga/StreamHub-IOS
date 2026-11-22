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
    @State private var editingWebsite: BrowserEntry?
    @State private var showingWebsiteEditor = false
    @State private var browserURL: BrowserDestination?
    @State private var error: String?

    var body: some View {
        Form {
            websites
            nativeSources
        }
        .navigationTitle("Streaming Sources")
        .sheet(item: $browserURL) { BrowserView(url: $0.url) }
        .sheet(isPresented: $showingWebsiteEditor) { WebsiteEditorView(bookmark: editingWebsite) }
        .alert("Could not add source", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK") { error = nil }
        } message: { Text(error ?? "") }
    }

    private var websites: some View {
        Section {
            if browser.bookmarks.isEmpty {
                Text("Add a website to see it first in Watch Now for movies and TV episodes.")
                    .foregroundStyle(.secondary)
            }
            ForEach(browser.sortedWebsites) { bookmark in websiteRow(bookmark) }
            Button {
                editingWebsite = nil
                showingWebsiteEditor = true
            } label: { Label("Add website", systemImage: "plus.circle") }
        } header: { Text("Streaming Websites") } footer: {
            Text("Browser destinations · Title availability is unverified. Favorites appear first. Some websites require Safari, an account, or a subscription.")
        }
    }

    private func websiteRow(_ bookmark: BrowserEntry) -> some View {
        HStack(spacing: 12) {
            Button { browserURL = BrowserDestination(url: bookmark.url) } label: {
                VStack(alignment: .leading, spacing: 5) {
                    Text(bookmark.title).foregroundStyle(.primary)
                    Text(bookmark.url.host ?? "Website").font(.caption).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.buttonStyle(.plain)
            Button { browser.toggleWebsiteFavorite(bookmark.id) } label: {
                Image(systemName: browser.isFavoriteWebsite(bookmark.id) ? "star.fill" : "star")
                    .frame(minWidth: 36, minHeight: 44)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(browser.isFavoriteWebsite(bookmark.id) ? "Unfavorite \(bookmark.title)" : "Favorite \(bookmark.title)")
            Menu {
                Button("Edit website", systemImage: "pencil") { edit(bookmark) }
                Button("Remove website", systemImage: "trash", role: .destructive) { browser.removeBookmark(bookmark.id) }
            } label: { Image(systemName: "ellipsis.circle").frame(minWidth: 36, minHeight: 44) }
            .accessibilityLabel("Manage \(bookmark.title)")
        }
        .swipeActions {
            Button("Remove", role: .destructive) { browser.removeBookmark(bookmark.id) }
            Button("Edit") { edit(bookmark) }.tint(.blue)
        }
    }

    private var nativeSources: some View {
        Section {
            Text("Add streams you own or have permission to play. StreamHub never extracts website video, unlocks subscriptions, or bypasses DRM.")
                .font(.callout).foregroundStyle(.secondary)
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
        } header: { Text("Native playback sources") }
    }

    private func edit(_ bookmark: BrowserEntry) {
        editingWebsite = bookmark
        showingWebsiteEditor = true
    }

    private func addStream() {
        guard let url = AuthorizedStreamPolicy.validate(streamAddress) else {
            error = "Enter a valid HTTPS URL without embedded username or password."; return
        }
        sources.add(name: streamName.trimmingCharacters(in: .whitespacesAndNewlines), url: url)
        streamName = ""; streamAddress = ""; authorized = false
    }
}

private struct WebsiteEditorView: View {
    let bookmark: BrowserEntry?
    @ObservedObject private var browser = BrowserData.shared
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var address: String
    @State private var favorite: Bool
    @State private var error: String?

    init(bookmark: BrowserEntry?) {
        self.bookmark = bookmark
        _name = State(initialValue: bookmark?.title ?? "")
        _address = State(initialValue: bookmark?.url.absoluteString ?? "")
        _favorite = State(initialValue: bookmark.map { BrowserData.shared.isFavoriteWebsite($0.id) } ?? false)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Website details") {
                    TextField("Website name", text: $name)
                    TextField("https://example.com", text: $address)
                        .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Toggle("Favorite website", isOn: $favorite)
                }
                Section {
                    Text("This saves a browser destination. StreamHub does not verify that this website has a selected movie or episode.")
                        .font(.callout).foregroundStyle(.secondary)
                    if let error { Text(error).foregroundStyle(.red).accessibilityAddTraits(.isStaticText) }
                }
            }
            .navigationTitle(bookmark == nil ? "Add website" : "Edit website")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }.preferredColorScheme(.dark).tint(.red)
    }

    private func save() {
        guard let url = WebAddress.parse(address) else {
            error = "Enter a valid website address without an embedded username or password."; return
        }
        if let bookmark {
            guard browser.updateWebsite(bookmark.id, title: name, url: url) else {
                error = "This address is already saved, or the website could not be updated."; return
            }
            if browser.isFavoriteWebsite(bookmark.id) != favorite { browser.toggleWebsiteFavorite(bookmark.id) }
        } else {
            guard browser.addWebsite(title: name, url: url, isFavorite: favorite) else {
                error = "This address is already saved. Edit the existing website instead."; return
            }
        }
        dismiss()
    }
}

struct BrowserDestination: Identifiable {
    let id = UUID()
    let url: URL
}
