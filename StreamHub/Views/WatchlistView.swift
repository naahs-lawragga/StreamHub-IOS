import SwiftUI
import StreamHubCore

struct WatchlistView: View {
    @EnvironmentObject private var store: AppStore
    @State private var filter = "All"
    private let columns = [GridItem(.adaptive(minimum: 132), spacing: 16, alignment: .top)]
    private var titles: [MediaTitle] {
        store.snapshot.watchlist.filter {
            filter == "All" || (filter == "Movies" ? $0.kind == .movie : $0.kind == .tv)
        }
    }

    var body: some View {
        Group {
            if store.snapshot.watchlist.isEmpty {
                ContentUnavailableView {
                    Label("Make it a movie night", systemImage: "bookmark")
                } description: {
                    Text("Save the stories you want to return to. Your watchlist is stored on this device.")
                } actions: {
                    Button("Explore Titles") { store.selectedTab = 0 }.buttonStyle(.borderedProminent)
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        Picker("Title type", selection: $filter) {
                            Text("All").tag("All"); Text("Movies").tag("Movies"); Text("TV Shows").tag("TV Shows")
                        }.pickerStyle(.segmented)
                        Text("\(titles.count) saved \(titles.count == 1 ? "story" : "stories")")
                            .font(.subheadline).foregroundStyle(.secondary)
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 22) {
                            ForEach(titles, id: \.key) { title in
                                NavigationLink { DetailView(title: title) } label: { PosterCard(title: title) }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        Button(role: .destructive) { store.toggleWatchlist(title) } label: {
                                            Label("Remove from Watchlist", systemImage: "bookmark.slash")
                                        }
                                    }
                                    .accessibilityAction(named: "Remove from Watchlist") { store.toggleWatchlist(title) }
                            }
                        }
                    }.padding(20)
                }
            }
        }.background(Brand.background).navigationTitle("Watchlist")
    }
}
