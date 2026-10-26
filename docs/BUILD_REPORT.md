# StreamHub 0.1.0 — first IPA delivery

Verified on 2026-10-26. This is the first development candidate, not a claim of 1.0 completion or physical-device certification.

## 1. Files created

The repository contains the actual SwiftUI app under `StreamHub/`, the independently testable Swift package under `Core/`, hosted iOS tests under `StreamHubTests/`, XcodeGen `project.yml`, `Config/Info.plist`, original branding and icon catalogs, privacy manifest, GitHub workflows, build/release scripts, and repository documentation/policies. `docs/screenshots/setup.png` is an actual simulator capture. The project is generated with XcodeGen; no placeholder Xcode project or mock app is substituted.

## 2. Features implemented

Home, Search, Discover, Watchlist, Settings; TMDB catalog/search/details/cast/trailers/TV seasons and episodes; runtime Keychain token configuration; local watchlist and histories; image/metadata caching; optional FMHY directory; regional TMDB/JustWatch provider guide; custom sites and authorized streams; persistent WKWebView browser; AVPlayer controls, source changes, resume, supported PiP/audio/subtitle features; and validated update checking, dismissal, installer preferences and tutorials.

There are no advertising SDKs, payment systems, stream-extraction bypasses, or fabricated website title-availability results. See [implementation status](IMPLEMENTATION_STATUS.md) for details.

## 3. GitHub repository status

Public repository: https://github.com/naahs-lawragga/StreamHub-IOS

Source and compiler fixes were committed and pushed with authorization. The initial connection failure was resolved by installing the Codex GitHub App. Tested app-source commit: `2079344830aa7676e856109770c9aaab44d9098a`. A subsequent documentation-only commit records this evidence without rebuilding unchanged app code.

## 4. Build status

**PASSED:** Xcode 26.3 on the GitHub-hosted macOS 15 ARM64 runner; simulator test build and Release iPhoneOS build.

Run: https://github.com/naahs-lawragga/StreamHub-IOS/actions/runs/40382193288

The first two attempts exposed PiP main-actor errors and a browser action type mismatch. Both were fixed before this successful run. Tests were not disabled or bypassed.

## 5. IPA artifact location

Download: https://github.com/naahs-lawragga/StreamHub-IOS/actions/runs/40382193288/artifacts/12677579391

- File inside ZIP: `StreamHub-unsigned.ipa`
- Version: **0.1.0**, build **3**
- Bundle identifier: **com.streamhub.ios**
- Minimum iOS: **17.0**
- Platform: **iPhoneOS**, ARM64 Mach-O executable
- Size: **1,232,693 bytes**
- SHA-256: `3ba8ae0f204f8636661a8075acd81424fb25257bb541a38a4b6b8713367f0e80`
- Artifact retention: until **2026-11-25** under the current 30-day policy

The downloaded IPA's checksum, ZIP integrity, Info.plist identity/platform and Mach-O header were independently checked after CI. This IPA is unsigned; import/sign using a compatible installation tool. See [iPhone installation instructions](INSTALLATION.md).

## 6. IPA source location

**Not published yet.** `docs/source.template.json` intentionally contains no fake release entries. `scripts/generate-source.py` and the disabled-by-default stable release workflow generate a real `source.json` only after publicly downloadable IPA assets pass checksum/size verification. Pages/release environment setup and an approved release tag remain required.

## 7. Update system status

Core validation and SwiftUI update screens are implemented and tested. The first development IPA has an empty `STREAMHUB_SOURCE_URL`, so it does not perform automatic checks against an unpublished source. Stable release builds embed the configured Pages URL. This first candidate must be updated manually; no silent installation or Apple credential collection is attempted.

## 8. Tests completed

- **31 Swift core tests passed on macOS** in CI (also passed on Linux).
- **8 hosted iOS simulator tests passed**: browser URL policy/bookmarks/history/errors, native invalid-stream handling, provider failure isolation and concurrency limits.
- **6 release-tool tests passed locally**: source version ordering, missing/draft/prerelease exclusions, asset host/size/checksum and HTTPS policy.
- Successful simulator launch captured in `docs/screenshots/setup.png`.
- Test report artifact: https://github.com/naahs-lawragga/StreamHub-IOS/actions/runs/40382193288/artifacts/12679866256
- Screenshot artifact: https://github.com/naahs-lawragga/StreamHub-IOS/actions/runs/40382193288/artifacts/12679851322

## 9. Remaining limitations

No physical iPhone 17, SideStore, LiveContainer multitasking/window resizing, hardware PiP, accessibility audit, or ProMotion profiling has been performed. Live TMDB requests require the user's token and were not tested with a real account. Authorized live stream/provider logins and website compatibility need on-device validation. TMDB provider listings are title-level reports, not verified episode/subscription access. No stable release or Pages source has been published. Consult the [compatibility checklist](COMPATIBILITY.md) before claiming device compatibility or 1.0 readiness.
