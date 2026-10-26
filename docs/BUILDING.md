# Building StreamHub

## Windows and GitHub Actions

1. Install Git and Visual Studio Code. Create `C:\iOSProjects\StreamHub` and check out the authorized `StreamHub-iOS` repository there.
2. Edit Swift source in `StreamHub/`, portable logic in `Core/`, and target settings in `project.yml`.
3. Review `git diff`, run available checks, commit, and push a branch. Never commit `Config/Local.xcconfig`, TMDB tokens, certificates, or provisioning profiles.
4. Open the GitHub Actions **Build unsigned IPA** run. Fix errors before treating a build as usable.
5. After a successful run, download the `StreamHub-unsigned-<commit>` artifact. GitHub wraps artifacts in ZIP files; extract it first.

Windows cannot compile the Apple SwiftUI/WebKit/AVKit application locally. Swift core tests can run on a supported Windows/Linux Swift environment, while the required Apple SDK checks run on macOS. Codex only inspects and fixes builds during an active authorized session.

## macOS

Use Xcode 16 or later, a recent available iOS simulator, Python 3, and XcodeGen 2.42.0. CI builds that pinned XcodeGen tag from its source repository. Xcode is selected from compatible installed runner versions and its version is printed in the log.

```sh
xcodegen generate
swift test --package-path Core
bash scripts/build-ios.sh
```

Open generated `StreamHub.xcodeproj` for development. The local SPM dependency is `Core`, product `StreamHubCore`; no external runtime SDK packages are needed. iOS 17 is the minimum deployment target, with iPhone and iPad layouts supported. Signing is disabled only for CI artifacts. For direct device debugging, choose your own development team in Xcode and enable normal signing.

Optional build configuration is documented in `Config/Local.xcconfig.example`. Enter a TMDB API Read Access Token in app Settings; do not embed it in an IPA. An unconfigured app displays its setup/empty state and the source-management/browser features remain available.

## Artifacts

- `build/StreamHub-unsigned.ipa`: validated device bundle, unsigned.
- `build/StreamHub-unsigned.ipa.sha256`: SHA-256 integrity checksum.
- `build/Tests.xcresult`: actual simulator test results.
- `build/screenshots/setup.png`: actual simulator capture with no test credentials.

Run `python3 -m unittest discover -s scripts -p 'test_*.py'` for the release metadata/packaging tooling checks. Core and integration tests use controlled fixtures and never require a live TMDB credential.
