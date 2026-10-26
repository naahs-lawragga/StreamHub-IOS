import AVFoundation
import AVKit
import Combine
import Foundation

@MainActor
final class PlayerModel: NSObject, ObservableObject {
    let player = AVPlayer()
    @Published private(set) var error: String?
    @Published private(set) var buffering = true
    @Published private(set) var playing = false
    @Published var speed: Float = 1
    @Published private(set) var pictureInPictureActive = false
    private var url: URL
    private var observations: [NSKeyValueObservation] = []
    private var notificationObservers: [NSObjectProtocol] = []
    private var timeObserver: Any?
    private var bufferingTimeout: Task<Void, Never>?
    private var progressHandler: ((Double, Double) -> Void)?
    private var resumePosition: Double = 0
    private var wasPlayingBeforeInterruption = false
    private var attached = false
    private var started = false

    init(url: URL) { self.url = url; super.init() }

    func changeURL(_ url: URL) { stop(); self.url = url }

    func start(resumeAt: Double, speed: Float, progress: @escaping (Double, Double) -> Void) {
        attached = true
        guard !started else { return }
        started = true
        self.speed = min(2, max(0.5, speed))
        progressHandler = progress
        resumePosition = resumeAt.isFinite ? max(0, resumeAt) : 0
        guard AuthorizedStreamPolicy.validate(url.absoluteString) != nil else {
            error = "Native playback requires a valid authorized HTTPS stream."; buffering = false; return
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch { self.error = "Audio could not start: \(error.localizedDescription)" }
        player.automaticallyWaitsToMinimizeStalling = true
        observations.append(player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            Task { @MainActor [weak self] in
                self?.buffering = player.timeControlStatus == .waitingToPlayAtSpecifiedRate
                self?.playing = player.timeControlStatus == .playing
                if player.timeControlStatus == .waitingToPlayAtSpecifiedRate { self?.armBufferingTimeout() }
                else { self?.bufferingTimeout?.cancel() }
            }
        })
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 5, preferredTimescale: 600), queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.saveProgress() }
        }
        observeAudio()
        loadItem()
    }

    private func loadItem() {
        error = nil
        buffering = true
        armBufferingTimeout()
        let item = AVPlayerItem(url: url)
        item.preferredForwardBufferDuration = 10
        player.replaceCurrentItem(with: item)
        // Replace the item observer when retrying; retain the player observer.
        if observations.count > 1 { observations.removeLast(observations.count - 1) }
        observations.append(item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard item === self.player.currentItem else { return }
                switch item.status {
                case .readyToPlay:
                    let duration = item.duration.seconds
                    let position = duration.isFinite && duration > 0 ? min(self.resumePosition, max(0, duration - 1)) : self.resumePosition
                    if position > 0 {
                        await self.player.seek(to: CMTime(seconds: position, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: CMTime(seconds: 1, preferredTimescale: 600))
                    }
                    guard item === self.player.currentItem else { return }
                    self.player.playImmediately(atRate: self.speed)
                case .failed:
                    self.error = item.error?.localizedDescription ?? "This stream is unavailable or uses an unsupported format."
                    self.buffering = false
                case .unknown: break
                @unknown default: break
                }
            }
        })
    }

    private func armBufferingTimeout() {
        bufferingTimeout?.cancel()
        bufferingTimeout = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(30)) } catch { return }
            guard let self, self.buffering else { return }
            self.error = "The stream is taking too long to load. Check your connection, retry, or change source."
            self.player.pause()
            self.buffering = false
        }
    }

    private func observeAudio() {
        let center = NotificationCenter.default
        notificationObservers.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] notification in
            let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let options = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            Task { @MainActor [weak self] in
                guard let self else { return }
                if type == AVAudioSession.InterruptionType.began.rawValue {
                    self.wasPlayingBeforeInterruption = self.player.rate != 0
                    self.player.pause(); self.saveProgress()
                } else if type == AVAudioSession.InterruptionType.ended.rawValue,
                          AVAudioSession.InterruptionOptions(rawValue: options).contains(.shouldResume), self.wasPlayingBeforeInterruption {
                    do {
                        try AVAudioSession.sharedInstance().setActive(true)
                        self.player.playImmediately(atRate: self.speed)
                    } catch { self.error = error.localizedDescription }
                }
            }
        })
        notificationObservers.append(center.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] notification in
            let reason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            if reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue {
                Task { @MainActor [weak self] in self?.player.pause(); self?.saveProgress() }
            }
        })
        notificationObservers.append(center.addObserver(forName: .AVPlayerItemFailedToPlayToEndTime, object: nil, queue: .main) { [weak self] notification in
            guard let failedItem = notification.object as? AVPlayerItem else { return }
            Task { @MainActor [weak self] in
                guard let self, failedItem === self.player.currentItem else { return }
                self.error = "Playback was interrupted. Check the connection or choose another source."
                self.buffering = false; self.saveProgress()
            }
        })
        notificationObservers.append(center.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: nil, queue: .main) { [weak self] notification in
            guard let endedItem = notification.object as? AVPlayerItem else { return }
            Task { @MainActor [weak self] in
                guard let self, endedItem === self.player.currentItem else { return }
                self.saveProgress()
            }
        })
        notificationObservers.append(center.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.player.currentItem?.preferredForwardBufferDuration = 2 }
        })
    }

    func togglePlayback() {
        if player.rate == 0 { player.playImmediately(atRate: speed) } else { player.pause() }
    }
    func setSpeed(_ speed: Float) { self.speed = speed; if player.rate != 0 { player.rate = speed } }
    func skip(_ seconds: Double) {
        let current = player.currentTime().seconds
        guard current.isFinite else { return }
        var target = max(0, current + seconds)
        if let duration = player.currentItem?.duration.seconds, duration.isFinite { target = min(target, duration) }
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600))
    }
    func saveProgress() {
        let position = player.currentTime().seconds
        let duration = player.currentItem?.duration.seconds ?? 0
        guard position.isFinite, position > 0 else { return }
        progressHandler?(position, duration.isFinite ? duration : 0)
    }
    func retry() {
        let position = player.currentTime().seconds
        if position.isFinite { resumePosition = position }
        loadItem()
    }
    func setPictureInPicture(_ active: Bool) {
        pictureInPictureActive = active
        if !active && !attached { stop() }
    }
    func detach() { attached = false; saveProgress(); if !pictureInPictureActive { stop() } }
    func stop() {
        saveProgress(); player.pause()
        bufferingTimeout?.cancel(); bufferingTimeout = nil
        if let timeObserver { player.removeTimeObserver(timeObserver); self.timeObserver = nil }
        observations.removeAll()
        notificationObservers.forEach(NotificationCenter.default.removeObserver)
        notificationObservers.removeAll()
        player.replaceCurrentItem(with: nil)
        progressHandler = nil
        started = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    deinit {
        bufferingTimeout?.cancel()
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        notificationObservers.forEach(NotificationCenter.default.removeObserver)
    }
}
