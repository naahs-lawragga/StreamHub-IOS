import SwiftUI
import StreamHubCore

enum InstallationMethod: String, CaseIterable, Identifiable {
    case sideStore = "SideStore"
    case liveContainer = "LiveContainer"
    case ask = "Ask Every Time"
    var id: String { rawValue }
}

@MainActor
final class UpdateManager: ObservableObject {
    @Published private(set) var available: UpdateRelease?
    @Published var showUpdate = false
    @Published private(set) var isChecking = false
    @Published private(set) var statusMessage = "Updates have not been checked yet."
    @Published private(set) var lastSuccessfulCheck: Date?
    let installedVersion: String
    let sourceURL: URL?
    private let defaults: UserDefaults
    private let client = UpdateClient()
    private let osVersion: String
    private let cacheKey = "updates.validatedFeed"
    private let dismissedKey = "updates.dismissedVersions"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        installedVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
        let rawURL = Bundle.main.object(forInfoDictionaryKey: "STREAMHUB_SOURCE_URL") as? String ?? ""
        let configured = URL(string: rawURL)
        sourceURL = configured.flatMap { UpdateFeed.isSecureURL($0) ? $0 : nil }
        let os = ProcessInfo.processInfo.operatingSystemVersion
        osVersion = "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"
        lastSuccessfulCheck = defaults.object(forKey: "updates.lastSuccess") as? Date
        if defaults.string(forKey: "updates.cachedSource") == sourceURL?.absoluteString,
           let data = defaults.data(forKey: cacheKey),
           let release = try? UpdateFeed.latest(in: data, operatingSystem: osVersion),
           UpdateFeed.isNewer(release, than: installedVersion) {
            available = release
            statusMessage = "Showing the last verified update information."
        }
        if sourceURL == nil { statusMessage = "The public update source is not configured in this build." }
    }

    func check(force: Bool = false) async {
        guard !isChecking, let sourceURL else { return }
        let lastAttempt = defaults.object(forKey: "updates.lastAttempt") as? Date
        guard force || UpdateReminderPolicy.shouldCheck(lastAttempt: lastAttempt) else { return }
        isChecking = true
        defaults.set(Date(), forKey: "updates.lastAttempt")
        defer { isChecking = false }
        do {
            let data = try await client.fetch(sourceURL: sourceURL, operatingSystem: osVersion)
            let release = try UpdateFeed.latest(in: data, operatingSystem: osVersion)
            available = UpdateFeed.isNewer(release, than: installedVersion) ? release : nil
            defaults.set(data, forKey: cacheKey)
            defaults.set(sourceURL.absoluteString, forKey: "updates.cachedSource")
            let now = Date()
            lastSuccessfulCheck = now
            defaults.set(now, forKey: "updates.lastSuccess")
            statusMessage = available == nil ? "You have the latest compatible stable version." : "StreamHub \(release.version) is available."
            if available != nil {
                let dismissed = Set(defaults.stringArray(forKey: dismissedKey) ?? [])
                showUpdate = force || UpdateReminderPolicy.shouldPresent(version: release.version, dismissedVersions: dismissed)
            }
        } catch is CancellationError {
            statusMessage = "Update check was cancelled."
        } catch {
            statusMessage = "\(error.localizedDescription)" + (available != nil ? " The saved update information is still available." : "")
        }
    }

    func dismissCurrent() {
        if let release = available {
            var dismissed = Set(defaults.stringArray(forKey: dismissedKey) ?? [])
            dismissed.insert(release.version)
            defaults.set(Array(dismissed).sorted(), forKey: dismissedKey)
        }
        showUpdate = false
    }

    func presentAvailable() { showUpdate = available != nil }
}
