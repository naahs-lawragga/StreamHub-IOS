# Installation and updating

## Download a development build on iPhone

1. In Safari, sign in to GitHub and open the repository's **Actions** tab.
2. Open a successful **Build unsigned IPA** run. Scroll to **Artifacts** and download `StreamHub-unsigned-<commit>`.
3. Open **Files → Downloads**, then tap the downloaded ZIP to extract it.
4. Import `StreamHub-unsigned.ipa` into SideStore or LiveContainer using the instructions below. Safari cannot install an unsigned IPA directly.
5. Keep the included SHA-256 checksum alongside the IPA. Workflow artifacts expire after 30 days; stable releases, when approved and published, have separate download links.


## SideStore

Follow the current [official SideStore setup](https://docs.sidestore.io/docs/installation/requirements) first. Download the successful CI artifact ZIP and extract the IPA. In SideStore, use the app import/add flow to select the IPA, then complete its signing and installation process. StreamHub never asks for your Apple Account password. Account limits and refresh requirements are controlled by Apple and SideStore.

Once a stable release and GitHub Pages source have actually been published, add that HTTPS source URL through SideStore's Sources interface. Refresh it and select the latest StreamHub version. The documented schemes are `sidestore://source?url=<encoded-source-url>` and `sidestore://install?url=<encoded-ipa-url>`; The current StreamHub tutorial uses HTTPS release/download links and manual installer instructions; it does not invoke these schemes. See [SideStore URL documentation](https://docs.sidestore.io/docs/advanced/url-schema) and [source documentation](https://docs.sidestore.io/docs/advanced/app-sources).

## LiveContainer

Install an official LiveContainer build following its [installation guide](https://livecontainer.github.io/docs/installation). Download the IPA from a successful artifact or approved GitHub Release, save it in Files, and import it using LiveContainer's add-app flow. StreamHub itself does not require JIT or jailbreak APIs.

For an update, back up the existing app data container first. Import the new IPA and use the host's replacement/update option for the existing app while retaining its data container. Do not delete the app or its data container to update it. Exact behavior varies with the host version; data preservation has not yet been verified on hardware. See [containers](https://livecontainer.github.io/docs/guides/containers-and-external-data) and [data management](https://livecontainer.github.io/docs/guides/data-management).

## Multitasking

The [official multitasking guide](https://livecontainer.github.io/docs/guides/multitask) requires iOS/iPadOS 16+ and retained LiveContainer app extensions. Convert the guest to a Shared App, hold its card, and select Multitask. Window modes depend on host and device; Native Window is an iPadOS feature. StreamHub has no extension of its own. Browser sessions, video fullscreen, PiP, and restoration still require the device tests in COMPATIBILITY.md.

## Troubleshooting

- If import fails, confirm you extracted the workflow ZIP and selected the `.ipa`, then compare its checksum with the included file.
- If signing fails, follow the installation tool's account/profile/refresh guidance. StreamHub cannot bypass code signing.
- If a website blocks embedded browsing, open it in Safari. Never disable TLS certificate verification.
- If video fails, confirm the URL is a compatible authorized HTTPS HLS/MP4 stream. DRM/authenticated pages may need their own browser/player.
- Missing catalog artwork usually means no TMDB token, expired credentials, or a network problem. Previously cached results may remain available offline.
