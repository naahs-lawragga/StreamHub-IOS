# Installation and updating

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

## LiveContainer

Install an official LiveContainer build following its [installation guide](https://livecontainer.github.io/docs/installation). Download the IPA from a successful artifact or approved GitHub Release, save it in Files, and import it using LiveContainer's add-app flow. StreamHub itself does not require JIT or jailbreak APIs.

For an update, back up the existing app data container first. Import the new IPA and use the host's replacement/update option for the existing app while retaining its data container. Do not delete the app or its data container to update it. Exact behavior varies with the host version; data preservation has not yet been verified on hardware. See [containers](https://livecontainer.github.io/docs/guides/containers-and-external-data) and [data management](https://livecontainer.github.io/docs/guides/data-management).

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
