# StreamHub 0.1.2 build and release report

Verified on 2026-11-22. StreamHub **0.1.2 is published**, and its public source lists 0.1.2 first followed by 0.1.1. The main build, tagged release, Pages deployment, and independent public-download checks passed. This remains an early development app with physical-device checks outstanding.

## 1. Files changed

The existing project was updated in place. Changes are in `ProviderPicker.swift`, `ViewingProviders.swift`, `SourceManagerView.swift`, `BrowserData.swift`, `DiscoverView.swift`, the update views/manager, TMDB provider parsing, release-source generation, and their tests. New `StreamHub/Directory/DirectoryStore.swift` shares directory state between Discover and Watch Now. New `Core/Sources/StreamHubCore/SourceInstallationLink.swift` builds the documented LiveContainer source link. `SourceSelectionTests.swift`, `SourceInstallationLinkTests.swift`, and `DirectoryStoreTests.swift` exercise source selection, installer links, and persisted directory favorites. The app retains its bundle identifier, Keychain service, library schema/path, browser bookmark/history records, and existing settings keys. See the [complete file diff from 0.1.1](https://github.com/naahs-lawragga/StreamHub-IOS/compare/b8077f8...v0.1.2).

## 2. Features implemented

**Streaming source selector:** Watch Now now displays **Streaming Websites** first for movies and TV episodes. Configured websites lead, with favorites first, followed by an optional FMHY preview with directory favorites first and a link to browse the full directory. Each website is labeled as an unverified browser destination and opens the built-in WKWebView. Website loading, cached fallback, empty states, refresh errors, and configured-site access operate independently of official-provider requests.

The underlying cause was UI wiring: the former selector placed TMDB providers first, placed bookmarks last, and never read the FMHY entries/favorites kept by Discover. FMHY integration was implemented; this update shares its directory state with the selector. Its official published Markdown wiki is website-directory data, without a movie/episode availability contract. StreamHub uses no invented availability API. Users can always configure their own websites.

Website management supports adding, editing, removing, and favoriting websites. **Official Watch Providers** retains TMDB/JustWatch metadata, regional selection, subscription/free/ad-supported/rental/purchase labels, and a show-level disclaimer for episodes. **Hide paid rentals & purchases** removes rental and purchase rows while retaining subscriptions and free options. TMDB provider deduplication now retains separate categories for the same provider. Authorized native streams remain available separately.

**LiveContainer updates:** The fullscreen update notification retains **UPDATE NOW**, **HOW TO UPDATE**, and **REMIND ME LATER**. When LiveContainer is selected, Update Now attempts `livecontainer://source?url=<encoded_source_url>` and opens the manual tutorial if iOS cannot open the link. How to Update follows the selected installation method; Ask Every Time offers a choice. The tutorial covers the nine source-installation steps, future source refreshes, retaining the existing data container where supported, Copy Source URL, and View GitHub Release. The handler and source parser were checked against released LiveContainer **3.8.0** code and its [official Sources documentation](https://livecontainer.github.io/docs/guides/sources).

The release-source generator retains canonical AltSource metadata and adds matching `buildNumber`/`screenshotURLs` aliases read by LiveContainer 3.8.0. Screenshot dimensions come from the actual CI PNG. There are no advertising changes, fabricated video URLs, protected-media extraction, or claims that a website offers a selected title.

## 3. GitHub repository status

Public repository: https://github.com/naahs-lawragga/StreamHub-IOS

Tested commit: `5b0dcf24bbc275e16ae3e487a049129399cc37c3`. Authorized changes are pushed, and immutable tag `v0.1.2` points to that tested app source. The successful release workflow is [run 45012459729](https://github.com/naahs-lawragga/StreamHub-IOS/actions/runs/45012459729), job `137177548994`. [Version 0.1.2](https://github.com/naahs-lawragga/StreamHub-IOS/releases/tag/v0.1.2) was published at **10:36:25 UTC** on 2026-11-22.

## 4. Build status

**MAIN BUILD PASSED:** [run 45011619856](https://github.com/naahs-lawragga/StreamHub-IOS/actions/runs/45011619856), job `137174978030`, completed core tests, hosted iOS simulator tests, and the Release iPhoneOS build using Xcode 26.3 on the macOS runner.

The first attempt exposed a Swift initialization error in the additive website-favorite migration. `BrowserData` now initializes favorites from a local decoded bookmark array before using instance state; the next full build passed. Tests were not disabled or bypassed. The tagged release also passed its own full workflow: simulator tests succeeded at **10:32:12 UTC** and the Release iPhoneOS build at **10:36:15 UTC**. [Pages run 45013311742](https://github.com/naahs-lawragga/StreamHub-IOS/actions/runs/45013311742), job `137180150132`, passed source validation, deployment, and hosted JSON/artwork checks.

## 5. IPA artifact location

[Download the public 0.1.2 IPA](https://github.com/naahs-lawragga/StreamHub-IOS/releases/download/v0.1.2/StreamHub-unsigned.ipa) and its [SHA-256 checksum](https://github.com/naahs-lawragga/StreamHub-IOS/releases/download/v0.1.2/StreamHub-unsigned.ipa.sha256).

- File: `StreamHub-unsigned.ipa`
- Version: **0.1.2**, build **3**
- Bundle identifier: **com.streamhub.ios**
- Minimum iOS: **17.0**
- Platform: **iPhoneOS**, ARM64 Mach-O executable
- Size: **1,385,449 bytes**
- SHA-256: `49efb4c5c5b3f6b80bf7cdd3129d5ad390b3abaa2e41f3b38c6edb263547cfc1`
- Separate [release IPA workflow artifact](https://github.com/naahs-lawragga/StreamHub-IOS/actions/runs/45012459729/artifacts/14750343548), retained for 90 days under the workflow policy.

The public download, checksum asset, ZIP integrity, Info.plist identity/version/platform/source URL, and Mach-O header were independently verified after publication. The successful main build also has its own development artifact; the checksum above identifies the published release. An unsigned IPA requires a compatible signing/import workflow; see [installation instructions](INSTALLATION.md).

## 6. IPA source location

**LIVE source:** https://naahs-lawragga.github.io/StreamHub-IOS/source.json

The source contains verified versions **0.1.2** and **0.1.1**, newest first. Release automation downloads public IPA assets over HTTPS, verifies checksum/size and Info.plist identity/version/build, and generates entries only for real stable releases. Pages revalidates that exact successful release run’s source artifact before deployment and checks the hosted JSON/artwork.

The hosted JSON, both version downloads, SHA-256 values, bundle metadata, icon, screenshot dimensions, and LiveContainer compatibility aliases were independently checked after deployment. [Verified source bundle artifact](https://github.com/naahs-lawragga/StreamHub-IOS/actions/runs/45012459729/artifacts/14750931733). `docs/source.template.json` remains an empty development template, not the live source.

## 7. Update system and data preservation

The published 0.1.2 IPA embeds the existing public source URL. Update detection retains semantic version comparison, compatible-OS filtering, six-hour active-use checks, cached offline state, and dismissed-version persistence. Future published versions are detected without continuously polling in the background or silently installing anything.

TMDB credentials remain in the existing Keychain service. Watchlist/history storage, app identity, and preferences are not reset. Legacy bookmarks retain UUIDs, dates, and their existing encoded records; favorite IDs use one additive key. Tests confirm legacy bookmark/history restoration, edit identity preservation, favorite persistence/removal, and unchanged viewing-region, playback-speed, and installation-method settings after website mutations. Real host installation can still change data access if a new container or signing identity is selected. The tutorial explains preserving the existing container where supported.

The original 0.1.0 development IPA lacks an embedded source URL and requires a manual update once. No Apple Account credentials are requested.

## 8. Tests completed

The successful tagged release passed **68 tests**: **37 Swift core tests**, **18 hosted iOS simulator tests**, and **13 Python release-tool tests**. The main build also passed its 37 core and 18 hosted iOS tests. [Release test evidence and screenshots](https://github.com/naahs-lawragga/StreamHub-IOS/actions/runs/45012459729/artifacts/14750627430).

Coverage includes:

- Semantic version comparison, compatible-version selection, update dismissal, invalid metadata, and offline behavior.
- LiveContainer source-link scheme/host/exact percent encoding, including nested query delimiters, plus signs, existing percent escapes, Unicode, and fragments after one decode; rejection of insecure or credential URLs.
- Configured website ordering, favorite priority, directory opt-in/preview limits/deduplication, movie and TV-episode request context, unchanged browser destinations, unsafe-link rejection, and rental/purchase filtering while retaining subscriptions/free providers.
- Legacy browser bookmark migration without rewriting saved records, website add/edit/delete/favorite persistence, identity/date retention, bounded browser history, and unrelated settings preservation.
- FMHY parser/cache/offline fallback and TMDB category retention, alongside existing networking, persistence, browser, provider-concurrency, and playback-error checks.
- Source metadata ordering, exclusions, aliases matching canonical fields, actual PNG dimensions, IPA identity/version/platform, public-download integrity, and HTTPS redirects.

Both public source entries were verified against their actual downloads. The latest 0.1.2 IPA matches the size/checksum above. Historical 0.1.1 remains **1,303,017 bytes**, SHA-256 `80587a9142fd996b3a4a47f09198f89d6fa5b36862b669298c842bbe85425bc6`, build **2**, minimum iOS **17.0**. The checked-in setup screenshot is the actual capture from the published 0.1.2 build, with no TMDB credential installed.

## 9. Remaining limitations

LiveContainer source/deep-link compatibility was reviewed in released code, without a real-device installation test. No physical iPhone 17, SideStore, LiveContainer data-preservation/multitasking/window-resizing, hardware PiP, accessibility audit, or ProMotion profiling has been performed. Live TMDB requests require the user’s token and were not tested with a real account. Website compatibility and provider logins depend on each site. FMHY entries are directory destinations; TMDB provider metadata is reported title-level availability, not confirmed episode/subscription access. See the [compatibility checklist](COMPATIBILITY.md).
