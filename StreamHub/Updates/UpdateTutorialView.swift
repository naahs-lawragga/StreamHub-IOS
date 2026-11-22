import SwiftUI
import UIKit
import StreamHubCore

struct UpdateTutorialView: View {
    let method: InstallationMethod
    @EnvironmentObject private var updates: UpdateManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step = 0
    @State private var copied = false
    @State private var openMessage: String?

    private struct Step {
        let title: String
        let text: String
        let symbol: String
    }
    private var steps: [Step] {
        if method == .liveContainer {
            return [
                Step(title: "Open LiveContainer", text: "Open your installed LiveContainer app. The Open StreamHub Source button below can take you directly to its Sources tab when supported.", symbol: "app.fill"),
                Step(title: "Go to Sources", text: "Tap the Sources tab in LiveContainer. Current LiveContainer releases support AltStore-compatible sources.", symbol: "list.bullet.rectangle.fill"),
                Step(title: "Tap the + button", text: "In Sources, tap + to add a source.", symbol: "plus.circle.fill"),
                Step(title: "Paste the StreamHub source", text: "Tap Copy Source URL below, return to LiveContainer, and paste the complete HTTPS source URL into its source field.", symbol: "doc.on.clipboard.fill"),
                Step(title: "Confirm the source", text: "Confirm adding the source. If LiveContainer says it already exists, use the existing StreamHub source and refresh it instead.", symbol: "checkmark.seal.fill"),
                Step(title: "Find StreamHub", text: "Expand the StreamHub source section and find StreamHub. Check the app name and newest compatible version.", symbol: "magnifyingglass"),
                Step(title: "Tap Install", text: "Tap Install for StreamHub. LiveContainer switches to Apps and starts its installation workflow using the latest source download.", symbol: "arrow.down.circle.fill"),
                Step(title: "Follow installation prompts", text: "Follow LiveContainer’s prompts. When updating, use its existing-app update or replacement option and retain the existing StreamHub data container when offered. Back up your data first; avoid deleting the existing app or container.", symbol: "externaldrive.fill"),
                Step(title: "Launch the updated app", text: "Launch StreamHub and check the version in Settings → Updates. Confirm your watchlist, TMDB connection, settings, and browser sessions. Container and signing changes may affect data access; device installation has not been verified by this project.", symbol: "play.fill")
            ]
        }
        return [
            Step(title: "Prepare SideStore", text: "Set up SideStore using its official instructions, including its current pairing and network requirements. StreamHub does not handle your Apple Account credentials.", symbol: "iphone"),
            Step(title: "Add the StreamHub source", text: "Copy the source URL below. In SideStore, open Sources from Browse and add the URL using the + control. Check that the listing is StreamHub before continuing. Labels may vary by SideStore version.", symbol: "plus.app.fill"),
            Step(title: "Choose the latest version", text: "Open the StreamHub listing and install the newest compatible stable version, or use the update offered for StreamHub in My Apps. SideStore handles signing and installation.", symbol: "arrow.down.circle.fill"),
            Step(title: "Return to StreamHub", text: "Open StreamHub and check the version in Settings → Updates. Continue using SideStore’s refresh process to keep your signing valid. Keep the same app identity to improve the chance of retaining local data.", symbol: "checkmark.circle.fill")
        ]
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    TutorialIllustration(step: step).frame(height: 180).accessibilityHidden(true)
                    Text("\(method == .liveContainer ? "LiveContainer" : "SideStore") · Step \(step + 1) of \(steps.count)")
                        .font(.caption.bold()).foregroundStyle(.red)
                    ProgressView(value: Double(step + 1), total: Double(steps.count)).tint(.red)
                    Label(steps[step].title, systemImage: steps[step].symbol).font(.title2.bold())
                    Text(steps[step].text).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    actionLinks
                    if method == .liveContainer { futureUpdates }
                    dataPreservation
                    HStack {
                        Button("Back") { changeStep(-1) }.disabled(step == 0)
                        Spacer()
                        if step < steps.count - 1 {
                            Button("Next") { changeStep(1) }.buttonStyle(.borderedProminent).tint(.red)
                        } else { Button("Done") { dismiss() }.buttonStyle(.borderedProminent).tint(.red) }
                    }
                    DisclosureGroup("Troubleshooting") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("No source or release yet? Public update links appear only after a successful, approved release.")
                            Text("Installation failed? Check free storage, network access, the minimum iOS version, and your installer’s signing status. Consult its official guide for current requirements.")
                            Text("Missing data? Avoid deleting the existing app or guest container. Restore a backup if available. A changed signing identity or a different data container can create a fresh installation.")
                            Text("Web video or Picture in Picture behaves differently inside LiveContainer? Try normal launching and record the iOS, LiveContainer, and StreamHub versions in your bug report.")
                        }.font(.callout).foregroundStyle(.secondary).padding(.top, 12)
                    }
                }.padding(24).frame(maxWidth: 600).frame(maxWidth: .infinity)
            }
            .background(Color.black).navigationTitle("How to update").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Close") { dismiss() } } }
            .preferredColorScheme(.dark)
        }
    }

    @ViewBuilder private var actionLinks: some View {
        if let url = updates.sourceURL {
            if method == .liveContainer {
                Button("Open StreamHub Source in LiveContainer", action: openLiveContainerSource)
                    .buttonStyle(.borderedProminent).tint(.red)
                if let openMessage { Text(openMessage).font(.callout).foregroundStyle(.secondary) }
            }
            Button(copied ? "Source URL copied" : "Copy Source URL") {
                UIPasteboard.general.string = url.absoluteString
                copied = true
            }.buttonStyle(.bordered)
            Text(url.absoluteString).font(.caption).textSelection(.enabled)
        } else {
            Text("The public source is not configured in this build. Open the GitHub release for the IPA and installation details.")
                .font(.caption).foregroundStyle(.secondary)
        }
        Link("View GitHub Release", destination: updates.releasePageURL).buttonStyle(.bordered)
        if method == .liveContainer {
            Link("Official LiveContainer Sources guide", destination: URL(string: "https://livecontainer.github.io/docs/guides/sources")!)
        } else {
            Link("Official SideStore guide", destination: URL(string: "https://docs.sidestore.io/")!)
        }
    }

    private var futureUpdates: some View {
        DisclosureGroup("For future LiveContainer updates") {
            VStack(alignment: .leading, spacing: 12) {
                Text("1. Open LiveContainer.")
                Text("2. Go to Sources.")
                Text("3. Refresh the StreamHub source using its menu (…) or swipe actions. Refresh All also reloads every source.")
                Text("4. Select the newest StreamHub version offered by the refreshed source.")
                Text("5. Tap Install and follow LiveContainer’s supported installation or replacement prompts for the existing app.")
            }.font(.callout).foregroundStyle(.secondary).padding(.top, 12)
        }
    }

    private var dataPreservation: some View {
        DisclosureGroup("Preserve your saved data") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Back up your existing StreamHub data before updating. Keep the same app identity and use your installer’s existing-app update or replacement flow when supported.")
                if method == .liveContainer {
                    Text("Keep or reselect the existing StreamHub data container when LiveContainer offers that choice. Do not delete the existing guest app or data container to update it. Different containers or signing identities can make saved settings, Keychain credentials, or website sessions unavailable.")
                    Link("LiveContainer data management", destination: URL(string: "https://livecontainer.github.io/docs/guides/data-management")!)
                    Text("The source workflow and deep link were checked against LiveContainer 3.8.0 documentation and source code. Installation and data preservation have not been tested on a real device.")
                }
            }.font(.callout).foregroundStyle(.secondary).padding(.top, 12)
        }
    }

    private func openLiveContainerSource() {
        guard let sourceURL = updates.sourceURL,
              let link = SourceInstallationLink.liveContainer(sourceURL: sourceURL) else { return }
        openURL(link) { accepted in
            openMessage = accepted
                ? "Continue in LiveContainer and follow its prompts. If the source did not open, use Copy Source URL and the manual steps above."
                : "LiveContainer could not be opened. Copy the source URL and follow the manual steps above, or view the GitHub release."
        }
    }
    private func changeStep(_ delta: Int) { withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { step += delta } }
}

/// Original geometric tutorial artwork rendered at the current display scale.
private struct TutorialIllustration: View {
    let step: Int
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Circle().fill(Color.red.opacity(0.09)).frame(width: 180, height: 180)
                RoundedRectangle(cornerRadius: 22).fill(Color(white: 0.09)).overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.25), lineWidth: 2)).frame(width: 100, height: 160)
                VStack(spacing: 10) {
                    Capsule().fill(Color.white.opacity(0.25)).frame(width: 25, height: 4)
                    RoundedRectangle(cornerRadius: 10).fill(.red.gradient).frame(width: 60, height: 60)
                        .overlay(PlayTriangle().fill(.white).frame(width: 22, height: 26).offset(x: 2))
                    ForEach(0..<3) { index in Capsule().fill(index <= step ? Color.red : Color.white.opacity(0.13)).frame(width: 60 - CGFloat(index * 10), height: 5) }
                }
                Circle().fill(Color.red).frame(width: 42, height: 42).overlay(Text("\(step + 1)").font(.title3.bold()).foregroundStyle(.white)).offset(x: 62, y: 48)
            }.frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}

private struct PlayTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in path.move(to: CGPoint(x: rect.minX, y: rect.minY)); path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY)); path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY)); path.closeSubpath() }
    }
}
