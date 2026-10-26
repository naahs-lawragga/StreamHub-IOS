# StreamHub 0.1.1 build and release report

Verified on 2026-10-26. Version 0.1.1 is published with guided TMDB setup and a live update source. This is an early development release; it does not establish physical-device compatibility or 1.0 readiness.

## 1. Files created

The repository contains the SwiftUI app under `StreamHub/`, the independently testable Swift package under `Core/`, hosted iOS tests under `StreamHubTests/`, XcodeGen `project.yml`, `Config/Info.plist`, original branding and icon catalogs, privacy manifest, GitHub workflows, build/release scripts, and repository documentation/policies. The Xcode project is generated with XcodeGen. The screenshots are actual simulator captures.

## 2. Features implemented

Home, Search, Discover, Watchlist, Settings; TMDB catalog/search/details/cast/trailers/TV seasons and episodes; runtime Keychain token configuration; local watchlist and histories; image/metadata caching; optional FMHY directory; regional TMDB/JustWatch provider guide; custom sites and authorized streams; persistent WKWebView browser; AVPlayer controls, source changes, resume, supported PiP/audio/subtitle features; and validated update checking, dismissal, installer preferences and tutorials.

Version 0.1.1 adds a five-step tutorial under **Settings → TMDB connection → Set up TMDB step by step**, including copyable application form details, read access token instructions, and iPhone troubleshooting.

There are no advertising SDKs, payment systems, stream-extraction bypasses, or fabricated website title-availability results. See [implementation status](IMPLEMENTATION_STATUS.md) for details.

## 3. GitHub repository status

Public repository: https://github.com/naahs-lawragga/StreamHub-IOS

Published release: https://github.com/naahs-lawragga/StreamHub-IOS/releases/tag/v0.1.1

The immutable `v0.1.1` app-source tag identifies commit `53d8366`. The successful release workflow ran from commit `7e0d9db`, which fixed the XcodeGen cache by retaining its required SettingPresets alongside the built tool. The release rebuilt the tagged app source without moving the tag or replacing a published IPA.

## 4. Build status

**PASSED:** the 0.1.1 release completed its Xcode 26.3 simulator tests and Release iPhoneOS build on GitHub's macOS 15 runner.

- [Release run 40386876850](https://github.com/naahs-lawragga/StreamHub-IOS/actions/runs/40386876850), job `121797393709`.
- Simulator tests succeeded at **19:33:30 UTC** on 2026-10-26.
- Device build succeeded at **19:40:52 UTC**; release published at **19:41:01 UTC**.
- [Pages run 40388969253](https://github.com/naahs-lawragga/StreamHub-IOS/actions/runs/40388969253) passed source validation, deployment, and hosted JSON/artwork checks.

The first 0.1.0 development IPA remains documented by [run 40382193288](https://github.com/naahs-lawragga/StreamHub-IOS/actions/runs/40382193288). The current release was tested independently; no tests were disabled or bypassed.

## 5. IPA artifact location

[Download the public 0.1.1 IPA](https://github.com/naahs-lawragga/StreamHub-IOS/releases/download/v0.1.1/StreamHub-unsigned.ipa) and its [SHA-256 checksum](https://github.com/naahs-lawragga/StreamHub-IOS/releases/download/v0.1.1/StreamHub-unsigned.ipa.sha256).

- File: `StreamHub-unsigned.ipa`
- Version: **0.1.1**, build **2**
- Bundle identifier: **com.streamhub.ios**
- Minimum iOS: **17.0**
- Platform: **iPhoneOS**, ARM64 Mach-O executable
- Size: **1,303,017 bytes**
- SHA-256: `80587a9142fd996b3a4a47f09198f89d6fa5b36862b669298c842bbe85425bc6`
- Separate [release IPA workflow artifact](https://github.com/naahs-lawragga/StreamHub-IOS/actions/runs/40386876850/artifacts/12682107738), retained for 90 days under the workflow policy.

The public download's SHA-256, ZIP integrity, Info.plist identity/version/platform/source URL, and Mach-O executable were independently checked after publication. This IPA is unsigned; import or sign it using a compatible installation tool. See [iPhone installation instructions](INSTALLATION.md).

## 6. IPA source location

**LIVE:** https://naahs-lawragga.github.io/StreamHub-IOS/source.json

The source contains the verified 0.1.1 download, build version, size, release notes, checksum, icon, and simulator screenshot. Both the release workflow and the separate Pages workflow validated the public IPA before deployment. The hosted JSON, IPA, icon, and screenshot were downloaded and checked independently after publication.

[Verified source bundle artifact](https://github.com/naahs-lawragga/StreamHub-IOS/actions/runs/40386876850/artifacts/12680728715).

`docs/source.template.json` remains an empty development template and is not the live source.

## 7. Update system status

The published 0.1.1 IPA embeds `https://naahs-lawragga.github.io/StreamHub-IOS/source.json`. Metadata validation, version comparison, and dismissal have automated test coverage; the SwiftUI update screens compile in the tested app. Automatic checks run on launch and activation when the previous check is at least six hours old, with a manual check in **Settings → Updates & installation**. Version 0.1.1 will not advertise itself as newer than an installed 0.1.1 build.

The original 0.1.0 development IPA has an empty `STREAMHUB_SOURCE_URL` and must be updated manually. In-app update behavior and installation still require device validation. No silent installation or Apple credential collection is attempted.

## 8. Tests completed

The successful 0.1.1 release run passed:

- **31 Swift core tests:** metadata/network/search/cache/provider handling, persistence, directory parsing, update metadata/version comparison/dismissal/offline behavior.
- **8 hosted iOS simulator tests:** browser URL policy/bookmarks/history/errors, native invalid-stream handling, provider failure isolation and concurrency limits.
- **11 Python release-tool tests:** source ordering, publication exclusions, asset identity, public IPA metadata, checksum/size checks, and HTTPS policy.
- Simulator launch and an actual setup screenshot; [release test evidence and screenshots](https://github.com/naahs-lawragga/StreamHub-IOS/actions/runs/40386876850/artifacts/12682182722).
- Public IPA and source validation during publication and independently after Pages deployment.

## 9. Remaining limitations

No physical iPhone 17, SideStore, LiveContainer multitasking/window resizing, hardware PiP, accessibility audit, or ProMotion profiling has been performed. Live TMDB requests require the user's token and were not tested with a real account. Authorized live streams, provider logins, and website compatibility need on-device validation. TMDB provider listings are title-level reports, not verified episode/subscription access. Consult the [compatibility checklist](COMPATIBILITY.md) before claiming device compatibility or 1.0 readiness.
