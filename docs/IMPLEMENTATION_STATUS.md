# Implementation and verification status

Initial candidate version: **0.1.0**. This is a working implementation candidate, not a declaration of 1.0 readiness.

## Implemented

- Native SwiftUI Home, Search, Discover, Watchlist, and Settings tabs with dark/red original branding, cinematic artwork, lazy rows, placeholders, accessibility labels, scalable text, and reduced-motion handling.
- TMDB trending/popular/top-rated/new-release feeds, cancellable debounced/paginated search, movie and television details, cast, trailers, recommendations, season/episode selection, and regional viewing-provider metadata.
- Runtime TMDB token storage in Keychain; async requests, bounded metadata/image caches, rate-limit/retry handling, offline metadata fallback, and pull-to-refresh.
- Atomic local watchlist, recent/search histories, episode selection, native playback progress, and resume. Websites do not generate fictional playback progress.
- Optional FMHY Markdown directory, categories, search, favorites, manual refresh and cached fallback, with explicit unverified-website labels.
- Provider protocol and bounded concurrent provider checks; TMDB/JustWatch title-level viewing guide, custom websites, and user-supplied authorized HTTPS streams.
- WKWebView address/navigation/loading/error UI, bookmarks/history, persistent cookies, last-page restoration, external-link confirmation, and web-process recovery.
- AVPlayer/AVPlayerViewController native playback, seeking, skip controls, playback speed, supported audio/subtitle/PiP controls, resume, source switching, buffering/error recovery, and interruption handling.
- Validated AltSource update parsing, semantic version comparison, compatible OS filtering, six-hour active-use checks, offline cached state, dismissal persistence, fullscreen update advisory, installer preference, and SideStore/LiveContainer tutorials.
- Generated Xcode project specification, macOS CI build/test/unsigned IPA packaging, original icon/logo/social preview, and release/source automation scripts.

## Verification evidence

- Swift 6.0.3 Linux compiled the Foundation-only StreamHubCore package.
- **31 package tests passed**: metadata/network/search/cache/provider handling, persistence, directory parsing, versions/update metadata/dismissal/offline behavior.
- **6 Python release-tool tests passed**: semantic ordering, publication exclusions, asset identity, checksums, sizes, and HTTPS policy.
- Full Xcode 26.3 simulator tests and Release iPhoneOS build passed in [Actions run 40382193288](https://github.com/naahs-lawragga/StreamHub-IOS/actions/runs/40382193288); 31 core tests and 8 hosted iOS tests passed.
- The downloaded IPA checksum, bundle identity, device platform, and Mach-O executable were independently verified.
- Info.plist and asset-catalog JSON parsed successfully.
- Browser and playback hosted XCTest tests passed on the simulator.

## Pending evidence / limitations

- The first unsigned IPA and real setup screenshot were produced successfully. See BUILD_REPORT.md for exact artifact links.
- No live TMDB request was tested with a user credential. The credential must be entered on-device in Settings.
- No iPhone 17, SideStore, LiveContainer, multitasking/window-resizing, PiP, or ProMotion hardware test has been performed. Use the documented device checklist.
- Website compatibility depends on each site's security, authentication, video, and DRM policies; progress is only tracked for native playback.
- TMDB provider metadata is title-level reported availability, not episode-level or subscription verification. Custom streams are associated with titles by the user.
- The public update source has no deployed release yet. The candidate's source URL is intentionally unconfigured; successful approved releases populate it through the release workflow.
- Browser cookies and last URL persist; an arbitrary website's live JavaScript state and back/forward stack are not restored across process termination.
- The README includes a real simulator setup screenshot. Hardware performance measurements remain pending. Artwork loads from TMDB; no movie catalog screenshot was fabricated.
- Stable release, GitHub Pages activation, repository branch/environment protection, and device compatibility certification are separate deployment/validation tasks.

## Repository / build handoff (2026-10-26)

- Public repository: https://github.com/naahs-lawragga/StreamHub-IOS
- The initial GitHub access blocker was resolved by installing the ChatGPT Codex Connector. Source and build fixes were committed and pushed under the user's authorization.
- Successful tested source commit: `2079344830aa7676e856109770c9aaab44d9098a`.
- Subsequent documentation-only evidence commit uses `[skip ci]`; app source is unchanged from the successful build.
- Unsigned IPA and checksum are uploaded to the successful Actions run. No stable release or GitHub Pages source has been published.
- See [BUILD_REPORT.md](BUILD_REPORT.md) for downloads and the complete nine-point delivery report.
