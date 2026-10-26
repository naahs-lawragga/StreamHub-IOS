import SwiftUI
import WebKit

struct BrowserView: View {
    @StateObject private var model: BrowserModel
    @ObservedObject private var data = BrowserData.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var libraryPresented = false

    init(url: URL) { _model = StateObject(wrappedValue: BrowserModel(url: url)) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: model.webView.url?.scheme == "https" ? "lock.fill" : "globe")
                        .foregroundStyle(.secondary).accessibilityHidden(true)
                    TextField("Website address", text: $model.address)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .keyboardType(.URL).submitLabel(.go).onSubmit { model.submitAddress() }
                        .accessibilityLabel("Website address")
                    Button { model.loading ? model.webView.stopLoading() : model.webView.reload() } label: {
                        Image(systemName: model.loading ? "xmark" : "arrow.clockwise")
                    }.accessibilityLabel(model.loading ? "Stop loading" : "Reload website")
                }
                .padding(12).background(.quaternary, in: RoundedRectangle(cornerRadius: 14)).padding(.horizontal)
                if model.loading { ProgressView(value: model.progress).tint(.red).padding(.top, 4) }
                if let error = model.error {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Website could not load", systemImage: "exclamationmark.triangle")
                            .font(.headline)
                        Text(error).font(.callout)
                        HStack {
                            Button("Reload") { model.submitAddress() }.buttonStyle(.borderedProminent)
                            if let url = model.webView.url ?? WebAddress.parse(model.address) {
                                Button("Open in Safari") { openURL(url) }.buttonStyle(.bordered)
                            }
                        }
                    }.padding().frame(maxWidth: .infinity, alignment: .leading)
                }
                BrowserSurface(webView: model.webView)
            }
            .background(Color.black)
            .navigationTitle(model.title).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    if let url = model.webView.url { ShareLink(item: url) }
                }
                ToolbarItemGroup(placement: .bottomBar) {
                    Button { model.webView.goBack() } label: { Image(systemName: "chevron.left") }
                        .disabled(!model.canGoBack).accessibilityLabel("Back")
                    Spacer()
                    Button { model.webView.goForward() } label: { Image(systemName: "chevron.right") }
                        .disabled(!model.canGoForward).accessibilityLabel("Forward")
                    Spacer()
                    Button {
                        if let url = model.webView.url { data.toggleBookmark(title: model.title, url: url) }
                    } label: {
                        Image(systemName: data.bookmarks.contains(where: { $0.url == model.webView.url }) ? "bookmark.fill" : "bookmark")
                    }.disabled(model.webView.url == nil).accessibilityLabel("Toggle bookmark")
                    Spacer()
                    Button { libraryPresented = true } label: { Image(systemName: "book") }
                        .accessibilityLabel("Bookmarks and history")
                    Spacer()
                    Button {
                        if let url = model.webView.url { openURL(url) }
                    } label: { Image(systemName: "safari") }.accessibilityLabel("Open in Safari")
                }
            }
            .sheet(isPresented: $libraryPresented) {
                BrowserLibraryView { url in model.load(url); libraryPresented = false }
            }
            .alert("Open external application?", isPresented: Binding(
                get: { model.externalURL != nil }, set: { if !$0 { model.externalURL = nil } }
            )) {
                Button("Open") { if let url = model.externalURL { openURL(url) }; model.externalURL = nil }
                Button("Cancel", role: .cancel) { model.externalURL = nil }
            } message: { Text(model.externalURL?.absoluteString ?? "") }
        }.preferredColorScheme(.dark).tint(.red)
    }
}

private struct BrowserSurface: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

struct BrowserLibraryView: View {
    @ObservedObject private var data = BrowserData.shared
    @Environment(\.dismiss) private var dismiss
    var open: (URL) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("Bookmarks") {
                    if data.bookmarks.isEmpty { Text("Save a website with the bookmark button.").foregroundStyle(.secondary) }
                    ForEach(data.bookmarks) { entry in
                        entryButton(entry).swipeActions {
                            Button("Delete", role: .destructive) { data.removeBookmark(entry.id) }
                        }
                    }
                }
                Section("Recent websites") {
                    if data.history.isEmpty { Text("No browsing history").foregroundStyle(.secondary) }
                    ForEach(data.history) { entryButton($0) }
                    if !data.history.isEmpty { Button("Clear browser history", role: .destructive) { data.clearHistory() } }
                }
            }.navigationTitle("Your websites")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }.preferredColorScheme(.dark).tint(.red)
    }

    private func entryButton(_ entry: BrowserEntry) -> some View {
        Button { open(entry.url) } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title).foregroundStyle(.primary).lineLimit(2)
                Text(entry.url.host ?? entry.url.absoluteString).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
