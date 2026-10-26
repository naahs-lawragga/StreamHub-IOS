import SwiftUI
import UIKit
import ImageIO
import StreamHubCore

enum Brand {
    static let red = Color(red: 0.95, green: 0.12, blue: 0.20)
    static let background = Color(red: 0.035, green: 0.035, blue: 0.045)
    static let surface = Color(red: 0.09, green: 0.09, blue: 0.11)
}

actor ImagePipeline {
    static let shared = ImagePipeline()
    private let memory = NSCache<NSURL, UIImage>()
    private var tasks: [URL: Task<UIImage?, Never>] = [:]
    private let session: URLSession

    init() {
        memory.totalCostLimit = 40 * 1_024 * 1_024
        memory.countLimit = 100
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(memoryCapacity: 8 * 1_024 * 1_024, diskCapacity: 150 * 1_024 * 1_024, diskPath: "streamhub.images")
        config.timeoutIntervalForRequest = 20
        config.httpMaximumConnectionsPerHost = 4
        session = URLSession(configuration: config)
    }

    func image(for url: URL) async -> UIImage? {
        if let cached = memory.object(forKey: url as NSURL) { return cached }
        if let running = tasks[url] { return await running.value }
        let session = session
        let task = Task<UIImage?, Never> {
            do {
                let (data, response) = try await session.data(from: url)
                guard let response = response as? HTTPURLResponse, response.statusCode == 200,
                      data.count < 20_000_000,
                      let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
                let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                             kCGImageSourceThumbnailMaxPixelSize: 1_280,
                                             kCGImageSourceCreateThumbnailWithTransform: true,
                                             kCGImageSourceShouldCacheImmediately: true]
                guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
                return UIImage(cgImage: image)
            } catch { return nil }
        }
        tasks[url] = task
        let result = await task.value
        tasks[url] = nil
        if let result { memory.setObject(result, forKey: url as NSURL, cost: (result.cgImage?.bytesPerRow ?? 0) * (result.cgImage?.height ?? 0)) }
        return result
    }

    func clear() { memory.removeAllObjects(); session.configuration.urlCache?.removeAllCachedResponses() }
    func releaseMemory() { memory.removeAllObjects() }
}

struct CachedImage: View {
    let url: URL?
    var contentMode: ContentMode = .fill
    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Brand.surface
                if let image {
                    Image(uiImage: image).resizable().aspectRatio(contentMode: contentMode)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                } else {
                    Image(systemName: failed ? "photo" : "film")
                        .font(.title2).foregroundStyle(.white.opacity(0.22))
                }
            }
        }
        .accessibilityHidden(true)
        .task(id: url) {
            image = nil; failed = false
            guard let url else { failed = true; return }
            let loaded = await ImagePipeline.shared.image(for: url)
            guard !Task.isCancelled else { return }
            image = loaded; failed = loaded == nil
        }
    }
}

struct PosterCard: View {
    let title: MediaTitle
    var width: CGFloat = 132

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            CachedImage(url: title.posterURL)
                .frame(width: width, height: width * 1.5)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(alignment: .topLeading) {
                    if title.voteAverage > 0 {
                        Label(title.voteAverage.formatted(.number.precision(.fractionLength(1))), systemImage: "star.fill")
                            .font(.caption2.bold()).foregroundStyle(.white)
                            .padding(.horizontal, 7).padding(.vertical, 5)
                            .background(.black.opacity(0.78), in: Capsule()).padding(8)
                    }
                }
            Text(title.displayTitle).font(.subheadline.weight(.semibold)).lineLimit(2).foregroundStyle(.white)
            Text("\(title.year) · \(title.kind == .movie ? "Movie" : "TV Series")")
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(width: width, alignment: .topLeading)
        .accessibilityElement(children: .combine)
    }
}

struct MediaRow: View {
    let heading: String
    let titles: [MediaTitle]

    var body: some View {
        if !titles.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                Text(heading).font(.title3.bold()).padding(.horizontal, 20).accessibilityAddTraits(.isHeader)
                ScrollView(.horizontal) {
                    LazyHStack(alignment: .top, spacing: 14) {
                        ForEach(titles, id: \.key) { title in
                            NavigationLink { DetailView(title: title) } label: { PosterCard(title: title) }
                                .buttonStyle(.plain)
                        }
                    }.padding(.horizontal, 20)
                }.scrollIndicators(.hidden)
            }
        }
    }
}

struct LoadingRows: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            RoundedRectangle(cornerRadius: 22).fill(Brand.surface).frame(height: 360)
            ForEach(0..<2) { _ in
                VStack(alignment: .leading, spacing: 14) {
                    RoundedRectangle(cornerRadius: 5).fill(Brand.surface).frame(width: 180, height: 24)
                    HStack(spacing: 14) {
                        ForEach(0..<3) { _ in
                            RoundedRectangle(cornerRadius: 14).fill(Brand.surface).frame(height: 200)
                        }
                    }
                }
            }
        }.padding(20).accessibilityLabel("Loading titles")
    }
}

struct RetryBanner: View {
    let message: String
    let retry: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(message, systemImage: "wifi.exclamationmark").font(.subheadline)
            Button("Try Again", action: retry).font(.subheadline.bold())
        }.padding().frame(maxWidth: .infinity, alignment: .leading)
            .background(Brand.surface, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct ConfigureMetadataView: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        ContentUnavailableView {
            Label("Your next favorite awaits", systemImage: "play.rectangle.on.rectangle.fill")
        } description: {
            Text("Connect your free TMDB API Read Access Token in Settings to discover movies and television. Your watchlist and browser stay available offline.")
        } actions: {
            Button("Connect TMDB") { store.selectedTab = 4 }.buttonStyle(.borderedProminent)
        }
    }
}
