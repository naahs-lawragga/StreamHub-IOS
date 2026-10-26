import SwiftUI
import UIKit

struct UpdateTutorialView: View {
    let method: InstallationMethod
    @EnvironmentObject private var updates: UpdateManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step = 0
    @State private var copied = false

    private struct Step {
        let title: String
        let text: String
        let symbol: String
    }
    private var steps: [Step] {
        if method == .liveContainer {
            return [
                Step(title: "Save the new IPA", text: "Open the official release below. Download StreamHub-unsigned.ipa and save it in Files. Keep a copy of your existing app data before changing its container.", symbol: "arrow.down.doc.fill"),
                Step(title: "Import in LiveContainer", text: "Open LiveContainer, use the + button, and choose the IPA from Files. Use its existing-app update or replacement option when offered; do not delete your current guest app first.", symbol: "square.and.arrow.down.fill"),
                Step(title: "Keep the same data container", text: "Select the existing StreamHub data container when LiveContainer offers that choice. Container replacement and signing changes can affect saved data and website sessions. Preservation is not guaranteed across all versions.", symbol: "externaldrive.fill"),
                Step(title: "Launch and check", text: "Launch StreamHub and check Settings → Updates for the new version. Confirm your watchlist and browser sessions. StreamHub’s LiveContainer and multitasking behavior still requires device testing.", symbol: "play.fill")
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
        if method == .liveContainer {
            if let release = updates.available {
                Link("Open latest release or IPA", destination: release.streamhubReleaseURL ?? release.downloadURL).buttonStyle(.bordered)
            }
            Link("Official LiveContainer guide", destination: URL(string: "https://livecontainer.github.io/")!)
        } else {
            if let url = updates.sourceURL {
                Button(copied ? "Source URL copied" : "Copy source URL") { UIPasteboard.general.url = url; copied = true }.buttonStyle(.bordered)
                Text(url.absoluteString).font(.caption).textSelection(.enabled)
            } else { Text("The public source is not configured in this build.").font(.caption).foregroundStyle(.secondary) }
            Link("Official SideStore guide", destination: URL(string: "https://docs.sidestore.io/")!)
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
