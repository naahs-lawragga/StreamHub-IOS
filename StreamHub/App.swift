import SwiftUI

@main
@MainActor
struct StreamHubApp: App {
    @StateObject private var store = AppStore()
    @StateObject private var updates = UpdateManager()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(updates)
                .preferredColorScheme(.dark)
                .tint(Brand.red)
                .task { await store.load(); await updates.check() }
                .fullScreenCover(isPresented: $updates.showUpdate) { UpdateScreen().environmentObject(updates) }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
                    Task { await ImagePipeline.shared.releaseMemory() }
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase != .active { Task { await store.flush() } }
                    else { Task { await updates.check() } }
                }
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var store: AppStore
    @SceneStorage("selectedTab") private var restoredTab = 0

    var body: some View {
        TabView(selection: $store.selectedTab) {
            NavigationStack { HomeView() }
                .tabItem { Label("Home", systemImage: "house.fill") }.tag(0)
            NavigationStack { SearchView() }
                .tabItem { Label("Search", systemImage: "magnifyingglass") }.tag(1)
            NavigationStack { DiscoverView() }
                .tabItem { Label("Discover", systemImage: "safari") }.tag(2)
            NavigationStack { WatchlistView() }
                .tabItem { Label("Watchlist", systemImage: "bookmark.fill") }.tag(3)
            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }.tag(4)
        }
        .onAppear { store.selectedTab = restoredTab }
        .onChange(of: store.selectedTab) { _, tab in restoredTab = tab }
        .alert("Storage needs attention", isPresented: Binding(
            get: { store.storageError != nil },
            set: { if !$0 { store.storageError = nil } }
        )) {
            Button("OK", role: .cancel) { store.storageError = nil }
        } message: { Text(store.storageError ?? "") }
    }
}
