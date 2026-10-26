import AVKit
import SwiftUI
import StreamHubCore

struct NativePlayerView: View {
    let title: MediaTitle
    let url: URL
    let episode: Episode?
    @StateObject private var model: PlayerModel
    @State private var activeURL: URL
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("defaultPlaybackSpeed") private var defaultSpeed = 1.0
    @AppStorage("resumePlayback") private var resumePlayback = true
    @State private var showSources = false

    init(title: MediaTitle, url: URL, episodeKey: String? = nil, episode: Episode? = nil) {
        self.title = title; self.url = url; self.episode = episode
        _model = StateObject(wrappedValue: PlayerModel(url: url))
        _activeURL = State(initialValue: url)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { model.saveProgress(); dismiss() } label: {
                    Image(systemName: "chevron.down").font(.title3.weight(.semibold)).padding(10)
                }.accessibilityLabel("Close player")
                VStack(alignment: .leading) {
                    Text(title.displayTitle).font(.headline).lineLimit(1)
                    if let episode { Text("S\(episode.seasonNumber) · E\(episode.episodeNumber)").font(.caption).foregroundStyle(.secondary) }
                }
                Spacer()
                Button("Change Source") { model.player.pause(); showSources = true }.font(.callout)
            }.padding(.horizontal)
            ZStack {
                PlayerSurface(model: model)
                if model.buffering && model.error == nil {
                    ProgressView("Buffering…").padding(20).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                        .allowsHitTesting(false)
                }
                if let error = model.error {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle").font(.largeTitle)
                        Text("Unable to play").font(.title2.bold())
                        Text(error).multilineTextAlignment(.center)
                        Text("Use an authorized HLS or MP4 stream. DRM and website authentication require the provider’s supported player.")
                            .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        Button("Retry") { model.retry() }.buttonStyle(.borderedProminent)
                        Button("Change Source") { showSources = true }.buttonStyle(.bordered)
                    }.padding(24).frame(maxWidth: 500).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20)).padding()
                }
            }
            HStack(spacing: 28) {
                Button { model.skip(-15) } label: { Image(systemName: "gobackward.15") }.accessibilityLabel("Back 15 seconds")
                Button { model.togglePlayback() } label: { Image(systemName: model.playing ? "pause.fill" : "play.fill") }
                    .accessibilityLabel(model.playing ? "Pause" : "Play")
                Button { model.skip(15) } label: { Image(systemName: "goforward.15") }.accessibilityLabel("Forward 15 seconds")
                Menu {
                    ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { speed in
                        Button("\(speed.formatted())×") { model.setSpeed(Float(speed)) }
                    }
                } label: { Text("\(Double(model.speed).formatted())×").font(.body.monospacedDigit()) }
                    .accessibilityLabel("Playback speed")
            }.font(.title2).padding().frame(maxWidth: .infinity)
        }
        .background(Color.black).foregroundStyle(.white).tint(.red).preferredColorScheme(.dark)
        .statusBarHidden()
        .onAppear { start(activeURL) }
        .onDisappear { model.detach() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                model.saveProgress()
                Task { await store.flush() }
            }
        }
        .sheet(isPresented: $showSources) {
            ProviderPicker(title: title, episode: episode, onSelectNative: { selectedURL in
                model.changeURL(selectedURL)
                activeURL = selectedURL
                start(selectedURL)
            }).environmentObject(store)
        }
    }

    private func start(_ selectedURL: URL) {
        let record = PlaybackRecord(title: title, episode: episode, streamURL: selectedURL)
        let saved = store.snapshot.playback.first { $0.id == record.id && $0.streamURL == selectedURL && !$0.isFinished }
        model.start(resumeAt: resumePlayback ? saved?.position ?? 0 : 0, speed: Float(defaultSpeed)) { position, duration in
            let updated = PlaybackRecord(title: title, episode: episode, streamURL: selectedURL, position: position, duration: duration)
            store.snapshot.playback.removeAll { $0.id == updated.id }
            store.snapshot.playback.insert(updated, at: 0)
            store.persist()
        }
    }
}

private struct PlayerSurface: UIViewControllerRepresentable {
    @ObservedObject var model: PlayerModel
    func makeCoordinator() -> Coordinator { Coordinator(model: model) }
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = model.player
        controller.delegate = context.coordinator
        controller.showsPlaybackControls = true
        controller.allowsPictureInPicturePlayback = true
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        controller.updatesNowPlayingInfoCenter = true
        return controller
    }
    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {}

    final class Coordinator: NSObject, AVPlayerViewControllerDelegate {
        let model: PlayerModel
        init(model: PlayerModel) { self.model = model }
        func playerViewControllerWillStartPictureInPicture(_ playerViewController: AVPlayerViewController) {
            model.setPictureInPicture(true)
        }
        func playerViewControllerDidStopPictureInPicture(_ playerViewController: AVPlayerViewController) {
            model.setPictureInPicture(false)
        }
        func playerViewController(_ playerViewController: AVPlayerViewController, failedToStartPictureInPictureWithError error: Error) {
            model.setPictureInPicture(false)
        }
        func playerViewController(_ playerViewController: AVPlayerViewController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
            completionHandler(playerViewController.viewIfLoaded?.window != nil)
        }
    }
}
