# Installation and updating

Version 0.1.2 adds website-first source selection and LiveContainer source installation. Its new build and publication are pending verification; the existing published 0.1.1 download remains below until that succeeds.

## Download version 0.1.1 on iPhone

Version 0.1.1 is published with the guided TMDB tutorial and a live update source.

1. In Safari, [download the unsigned IPA](https://github.com/naahs-lawragga/StreamHub-IOS/releases/download/v0.1.1/StreamHub-unsigned.ipa) and save it in Files. The [release page](https://github.com/naahs-lawragga/StreamHub-IOS/releases/tag/v0.1.1) also includes release notes and the SHA-256 checksum.
2. Import or sign the IPA with SideStore or LiveContainer as described below. Safari cannot install an unsigned IPA directly.
3. For SideStore source-based updates, add `https://naahs-lawragga.github.io/StreamHub-IOS/source.json` in Sources.

See the [build report](BUILD_REPORT.md) for verified size, checksum, and CI evidence. A GitHub Actions artifact is a ZIP containing the IPA; the release asset above is the IPA itself.

## Download a development build on iPhone

1. In Safari, sign in to GitHub and open the repository's **Actions** tab.
2. Open a successful **Build unsigned IPA** run. Scroll to **Artifacts** and download `StreamHub-unsigned-<commit>`.
3. Open **Files → Downloads**, then tap the downloaded ZIP to extract it.
4. Import `StreamHub-unsigned.ipa` into SideStore or LiveContainer using the instructions below. Safari cannot install an unsigned IPA directly.
5. Keep the included SHA-256 checksum alongside the IPA. Main-branch workflow artifacts expire after 30 days. The published 0.1.1 release has the separate public download link above.


## SideStore

Follow the current [official SideStore setup](https://docs.sidestore.io/docs/installation/requirements) first. Download the published IPA above, or extract the IPA from a successful CI artifact ZIP. In SideStore, use the app import/add flow to select the IPA, then complete its signing and installation process. StreamHub never asks for your Apple Account password. Account limits and refresh requirements are controlled by Apple and SideStore.

Add `https://naahs-lawragga.github.io/StreamHub-IOS/source.json` through SideStore's **Sources** interface. Refresh the source, open StreamHub, and choose its latest version. SideStore handles signing and installation. The StreamHub tutorial uses HTTPS download links and manual installer instructions. See the [official source documentation](https://docs.sidestore.io/docs/advanced/app-sources).

## LiveContainer sources

Install an official LiveContainer build following its [installation guide](https://livecontainer.github.io/docs/installation). The [official Sources guide](https://livecontainer.github.io/docs/guides/sources) documents AltStore-style sources and source deep links. StreamHub uses the same public source as SideStore:

```text
https://naahs-lawragga.github.io/StreamHub-IOS/source.json
```

In StreamHub, choose **Settings → Updates & installation → Installation Method → LiveContainer**. **UPDATE NOW** attempts to open the source in LiveContainer with `livecontainer://source?url=<encoded_source_url>`. The entire nested HTTPS URL is percent-encoded once. If iOS cannot open the link, StreamHub shows the manual guide. **HOW TO UPDATE** opens that method’s instructions. **Copy Source URL** and **View GitHub Release** remain available as fallbacks.

Add the source manually:

1. Open LiveContainer.
2. Go to the **Sources** tab.
3. Tap **+**.
4. Paste StreamHub’s public source URL above.
5. Confirm the source.
6. Find StreamHub in the source.
7. Tap **Install**.
8. Follow LiveContainer’s installation prompts.
9. Launch the updated app.

For future updates:

1. Open LiveContainer.
2. Go to **Sources**.
3. Refresh the StreamHub source using its menu or refresh action.
4. Select the newest StreamHub version offered by the source.
5. Install it using LiveContainer’s supported workflow.

Back up the existing StreamHub data container before updating. When LiveContainer offers an existing-app replacement/update choice, choose the existing StreamHub app and retain its current data container. Do not delete the app or its container first. A different container or signing identity may produce a fresh installation; data preservation depends on the host version and choices made during installation. See [containers](https://livecontainer.github.io/docs/guides/containers-and-external-data) and [data management](https://livecontainer.github.io/docs/guides/data-management).

Source parsing and the deep-link handler were inspected in the current LiveContainer **3.8.0** release. This is a source-code compatibility check, not a claim that installation, data preservation, or multitasking was tested on a real device. If the source is already present, refresh the existing source instead of adding a duplicate. Manual IPA import from GitHub Releases remains available if source installation fails.

## Streaming websites

In movie and TV episode **Watch Now**, **Streaming Websites** appears before **Official Watch Providers**. Configured browser websites appear first, with favorites first. Add, edit, remove, or favorite websites in **Settings → Streaming Sources → Websites & authorized streams**. Selecting a website opens the built-in WKWebView browser.

Enable the optional FMHY directory to browse its cached website list and favorites. FMHY’s published Markdown directory is website-discovery data; it does not verify availability for a movie or episode. A directory error does not prevent configured websites from opening. **Hide paid rentals & purchases** hides TMDB rental and purchase entries; legitimate subscription, free, and ad-supported provider metadata remains in **Official Watch Providers**.

## Connect TMDB in version 0.1.1

1. Open **Settings → TMDB connection → Set up TMDB step by step**.
2. Follow the guide to sign in to TMDB, request API access when needed, and complete the application form using the copyable project details. Use your own accurate contact information.
3. Copy the complete **API Read Access Token** from your [TMDB API settings](https://www.themoviedb.org/settings/api). The separate **API Key (v3 auth)** is not accepted by StreamHub’s token field.
4. Return to StreamHub, tap **Enter My Token**, paste only the token, and tap **Save token**. Do not add `Bearer` or quotation marks.
5. Open Home or Search. The token stays in the device Keychain; StreamHub never needs your TMDB password.

If the API registration form is difficult to use on iPhone, follow the tutorial’s Safari desktop-site guidance or use a desktop browser. Keep the token out of screenshots, issues, and public repositories.

## Update checks

Version 0.1.1 is configured to check the source above while the app is in use. Open **Settings → Updates & installation** to check manually or select SideStore, LiveContainer, or Ask Every Time. The live source currently offers 0.1.1; an installed 0.1.1 app should not show an update until a newer version is published. The original 0.1.0 development IPA has no configured update source and needs a manual IPA update.

## Multitasking

The [official multitasking guide](https://livecontainer.github.io/docs/guides/multitask) requires iOS/iPadOS 16+ and retained LiveContainer app extensions. Convert the guest to a Shared App, hold its card, and select Multitask. Window modes depend on host and device; Native Window is an iPadOS feature. StreamHub has no extension of its own. Browser sessions, video fullscreen, PiP, and restoration still require the device tests in COMPATIBILITY.md.

## Troubleshooting

- If import fails, confirm you extracted the workflow ZIP and selected the `.ipa`, then compare its checksum with the included file.
- If signing fails, follow the installation tool's account/profile/refresh guidance. StreamHub cannot bypass code signing.
- If a website blocks embedded browsing, open it in Safari. Never disable TLS certificate verification.
- If video fails, confirm the URL is a compatible authorized HTTPS HLS/MP4 stream. DRM/authenticated pages may need their own browser/player.
- Missing catalog artwork usually means no TMDB token, expired credentials, or a network problem. Previously cached results may remain available offline.
