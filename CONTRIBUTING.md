# Contributing

Use Swift 5 language mode, iOS 17 APIs, and Xcode 16 or later. Read [BUILDING](docs/BUILDING.md), run `swift test --package-path Core`, and run `bash scripts/build-ios.sh` on macOS before opening a pull request. Linux can run the Foundation-only core tests; it cannot build an iOS IPA.

Keep changes focused. Explain the concrete problem, resulting behavior, and test evidence. Include actual screenshots for visible changes and note device testing limitations. Do not label simulator results as device compatibility.

Never submit credentials, copyrighted movies, scraped protected streams, private Apple APIs, advertising SDKs, or changes that bypass provider access controls. Provider integrations must disclose the scope of verified availability. Original contributions are offered under the MIT license. Identify third-party data and its license separately.

Use semantic versioning. Maintainers approve release tags and the `release` environment; ordinary commits produce workflow artifacts, not stable releases. Do not force-push shared branches.
