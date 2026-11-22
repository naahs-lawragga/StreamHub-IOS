import SwiftUI
import UIKit
import StreamHubCore

struct UpdateScreen: View {
    @EnvironmentObject private var updates: UpdateManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL
    @AppStorage("installationMethod") private var method = InstallationMethod.ask.rawValue
    @State private var tutorialMethod: InstallationMethod?
    @State private var askMethod = false
    @State private var appeared = false
    @State private var choosingForUpdate = false
    @State private var copiedSource = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            LinearGradient(colors: [.red.opacity(0.42), .black, .black], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            if let release = updates.available {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Image(systemName: release.streamhubSecurityUpdate == true ? "checkmark.shield.fill" : "arrow.down.app.fill")
                            .font(.system(size: 80, weight: .bold)).foregroundStyle(.red)
                            .accessibilityHidden(true)
                        Text(release.streamhubSecurityUpdate == true ? "SECURITY UPDATE" : "UPDATE AVAILABLE!")
                            .font(.caption.weight(.heavy)).tracking(3).foregroundStyle(.red)
                        Text("A new chapter\nfor StreamHub.").font(.largeTitle.bold())
                        Text("StreamHub v\(release.version) is ready!").font(.title2.weight(.semibold))
                        HStack(alignment: .top) {
                            versionLabel("CURRENT", updates.installedVersion)
                            Spacer()
                            Image(systemName: "arrow.right").accessibilityHidden(true)
                            Spacer()
                            versionLabel("LATEST", release.version)
                        }
                        .padding().background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
                        if release.streamhubSecurityUpdate == true {
                            Label("This release includes security improvements. Update when you can; you can keep using StreamHub in the meantime.", systemImage: "shield.lefthalf.filled")
                                .font(.callout).foregroundStyle(.orange)
                        }
                        VStack(alignment: .leading, spacing: 12) {
                            Text("What’s new").font(.title3.bold())
                            Text(release.localizedDescription ?? "See the release page for the latest improvements.")
                                .font(.body).foregroundStyle(.white.opacity(0.82)).textSelection(.enabled)
                            Text(ByteCountFormatter.string(fromByteCount: release.size, countStyle: .file) + " download")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Button(action: beginUpdate) {
                            Label("UPDATE NOW", systemImage: "arrow.down.circle.fill").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 8)
                        }.buttonStyle(.borderedProminent).tint(.red)
                        Button("HOW TO UPDATE", action: showInstructions)
                            .buttonStyle(.bordered).frame(maxWidth: .infinity)
                        Button("REMIND ME LATER") { updates.dismissCurrent() }.frame(maxWidth: .infinity).foregroundStyle(.secondary)
                        if let sourceURL = updates.sourceURL {
                            Button(copiedSource ? "Source URL copied" : "Copy Source URL") {
                                UIPasteboard.general.string = sourceURL.absoluteString
                                copiedSource = true
                            }
                        }
                        Link("View GitHub Release", destination: updates.releasePageURL)
                        Text("Installation is handled by your chosen app. StreamHub never asks for your Apple Account password.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }.padding(28).frame(maxWidth: 620).frame(maxWidth: .infinity)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared || reduceMotion ? 0 : 20)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { withAnimation(reduceMotion ? nil : .easeOut(duration: 0.35)) { appeared = true } }
        .confirmationDialog("Choose your installation method", isPresented: $askMethod, titleVisibility: .visible) {
            Button("SideStore") { tutorialMethod = .sideStore }
            Button("LiveContainer") {
                if choosingForUpdate { openLiveContainerSource() } else { tutorialMethod = .liveContainer }
            }
        }
        .sheet(item: $tutorialMethod) { method in UpdateTutorialView(method: method).environmentObject(updates) }
    }

    private func versionLabel(_ label: String, _ version: String) -> some View {
        VStack(alignment: .leading, spacing: 6) { Text(label).font(.caption2.bold()).foregroundStyle(.secondary); Text(version).font(.title3.bold()) }
    }
    private func beginUpdate() {
        switch InstallationMethod(rawValue: method) ?? .ask {
        case .sideStore: tutorialMethod = .sideStore
        case .liveContainer: openLiveContainerSource()
        case .ask: choosingForUpdate = true; askMethod = true
        }
    }
    private func showInstructions() {
        switch InstallationMethod(rawValue: method) ?? .ask {
        case .sideStore: tutorialMethod = .sideStore
        case .liveContainer: tutorialMethod = .liveContainer
        case .ask: choosingForUpdate = false; askMethod = true
        }
    }
    private func openLiveContainerSource() {
        guard let sourceURL = updates.sourceURL,
              let link = SourceInstallationLink.liveContainer(sourceURL: sourceURL) else {
            tutorialMethod = .liveContainer
            return
        }
        // A successful handoff does not establish that LiveContainer imported or
        // installed the source. Its own prompts remain authoritative.
        openURL(link) { accepted in
            if !accepted { tutorialMethod = .liveContainer }
        }
    }
}

struct UpdateSettingsView: View {
    @EnvironmentObject private var updates: UpdateManager
    @AppStorage("installationMethod") private var method = InstallationMethod.ask.rawValue
    @State private var copiedSource = false
    var body: some View {
        Form {
            Section("Installed") { LabeledContent("Version", value: updates.installedVersion) }
            Section("Updates") {
                if let release = updates.available {
                    Button { updates.presentAvailable() } label: { Label("Version \(release.version) available", systemImage: "arrow.down.circle.fill").foregroundStyle(.red) }
                }
                Text(updates.statusMessage).font(.callout).foregroundStyle(.secondary)
                if let date = updates.lastSuccessfulCheck { LabeledContent("Last checked", value: date.formatted(date: .abbreviated, time: .shortened)) }
                Button { Task { await updates.check(force: true) } } label: {
                    HStack { Text("Check for Updates"); Spacer(); if updates.isChecking { ProgressView() } }
                }.disabled(updates.isChecking || updates.sourceURL == nil)
            }
            Section {
                Picker("Installation Method", selection: $method) { ForEach(InstallationMethod.allCases) { Text($0.rawValue).tag($0.rawValue) } }
                NavigationLink("SideStore guide") { UpdateTutorialView(method: .sideStore) }
                NavigationLink("LiveContainer guide") { UpdateTutorialView(method: .liveContainer) }
            } footer: { Text("Automatic checks run on launch and when you return, at most once every six hours. No background polling or silent installation.") }
            if let url = updates.sourceURL {
                Section("App source") {
                    Button(copiedSource ? "Source URL copied" : "Copy source URL") {
                        UIPasteboard.general.url = url
                        copiedSource = true
                    }
                    ShareLink(item: url) { Label("Share source URL", systemImage: "square.and.arrow.up") }
                    Text(url.absoluteString).font(.caption).textSelection(.enabled)
                }
            }
        }.navigationTitle("Updates")
    }
}
