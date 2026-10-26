<p align="center"><img src="docs/branding/logo.svg" width="180" alt="StreamHub logo"></p>

# StreamHub

A native, open-source iOS movie and television discovery app. Explore cinematic artwork, save a watchlist, browse viewing options, and play compatible streams you are authorized to access. Original SwiftUI interface, black surfaces, red accents, and no advertising.

**Development status:** 0.1.0 candidate. An IPA is available only after the macOS workflow succeeds. SideStore, LiveContainer, iPhone 17 ProMotion performance, and multitasking require device testing; compatibility is not certified.

## Features

- Home, Search, Discover, Watchlist, and Settings tabs with Dynamic Type and accessibility support.
- Official TMDB trending, popular and top-rated feeds; debounced search; movie and TV details, cast, trailers, seasons and episodes.
- Local watchlist, recently viewed titles, search history, and supported native playback progress.
- Regional provider listings with explicit title-level scope, a persistent WKWebView browser, favorites, and user-managed sources.
- AVPlayer playback of compatible authorized HTTPS HLS/MP4, system controls, audio/subtitle selection, and Picture-in-Picture where supported.
- Optional cached FMHY directory browsing. Directory links do not verify a title's availability.
- Validated update metadata, version comparison, dismissed-version persistence, and SideStore/LiveContainer tutorials.

## Get started

Use iOS 17 or later. On first launch, enter your own [TMDB API Read Access Token](https://www.themoviedb.org/settings/api) in Settings. It stays on the device and is never required in GitHub Actions. Browse metadata without supplying a streaming subscription; individual providers may require their own accounts.

On Windows, place the checkout at `C:\iOSProjects\StreamHub`. Edit with Visual Studio Code and push approved changes to GitHub. GitHub Actions supplies the macOS/Xcode build environment. See [building](docs/BUILDING.md) and [installation](docs/INSTALLATION.md).

After a successful **Build unsigned IPA** run, download the `StreamHub-unsigned-<commit>` artifact from the run's Summary page. Extract the ZIP to obtain `StreamHub-unsigned.ipa` and its checksum. The IPA must be signed or imported by a compatible installation tool; it is not an App Store distribution.

## Screenshots

Real simulator captures are produced by CI as the `StreamHub-simulator-screenshot` artifact. No screenshot has been claimed until that workflow runs. Captures without a TMDB token show the setup state. Movie artwork is retrieved from TMDB at runtime, not copied into this repository.

## Build and test

On macOS with Xcode 16 or later and XcodeGen 2.42.0:

```sh
swift test --package-path Core
bash scripts/build-ios.sh
```

The script generates `StreamHub.xcodeproj`, resolves the local Swift package, runs core and iOS tests, captures the simulator, builds for iPhoneOS, validates the bundle, and packages `build/StreamHub-unsigned.ipa`.

## Releases and updates

Ordinary main-branch pushes produce artifacts, not releases. A maintainer-approved stable semantic-version tag can invoke the separate release workflow. The update source is generated only after an IPA exists and its public URL and checksum are verified. No hosted source URL is asserted during initial development. See [releases](docs/RELEASING.md).

## Compatibility and roadmap

See the [device test matrix](docs/COMPATIBILITY.md). WKWebView cannot guarantee support for every provider; access controls and DRM remain in force. Native playback progress applies only to AVPlayer sessions. The app does not extract protected streams, claim FMHY title availability, or bypass signing.

Milestones: 0.1 discovery and first successful IPA; 0.2 browser and player hardening; 0.3 directory/providers/resume; 0.4 measured performance and LiveContainer validation; 1.0 device-tested polish and approved public release. Features may land ahead of their validation milestone.

## Contributing and credits

Read [CONTRIBUTING](CONTRIBUTING.md), [SECURITY](SECURITY.md), and [third-party notices](docs/THIRD_PARTY.md). This product uses the TMDB API but is not endorsed or certified by TMDB. Watch-provider information originates from TMDB/JustWatch. FMHY is an independent website directory. StreamHub is unaffiliated with these services, SideStore, LiveContainer, Netflix, or Apple.

Original code and StreamHub artwork use the [MIT license](LICENSE). Third-party material retains its own terms.
