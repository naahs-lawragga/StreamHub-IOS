# Releases and public IPA source

**Current status:** [v0.1.2 is published](https://github.com/naahs-lawragga/StreamHub-IOS/releases/tag/v0.1.2) and the [IPA source is live](https://naahs-lawragga.github.io/StreamHub-IOS/source.json), with 0.1.2 first followed by 0.1.1. The [release run](https://github.com/naahs-lawragga/StreamHub-IOS/actions/runs/45012459729) passed 37 core, 18 iOS, and 13 Python tests; the [Pages run](https://github.com/naahs-lawragga/StreamHub-IOS/actions/runs/45013311742) passed deployment and public-download validation. Independent checks verified both listed IPAs and the latest checksum, bundle metadata, source, and artwork on 2026-11-22. This is an early development release, with device testing still pending. Full evidence is in [BUILD_REPORT.md](BUILD_REPORT.md).

Normal main-branch builds produce unsigned IPA artifacts without publishing a stable release. `release.yml` runs for an approved stable version tag (`vX.Y.Z`), or a manual dispatch naming an existing approved tag. Publication for the initial StreamHub release/source has been explicitly authorized by the repository owner. No additional repository variable or mandatory reviewer is required by the workflow.

Repository owners can optionally protect version tags and add reviewers to the `release` environment for future releases. These are administrative preferences, not extra approval requirements inferred by the application. GitHub Pages must be enabled with **GitHub Actions** selected as its source; that repository setting requires administrative access.

1. Finish the change on main, run the build workflow, and inspect its actual results.
2. Add a `## X.Y.Z` section to CHANGELOG.md describing the release. These exact notes become the release body, followed by a signing/compatibility note.
3. Create the authorized annotated `vX.Y.Z` tag at a reviewed main-branch commit and push it. Prerelease tags and tags not reachable from main are rejected. Do not force-update published tags.
4. The workflow rebuilds and tests, validates the device bundle, computes SHA-256, and uploads a separate IPA workflow artifact before attempting publication. It then publishes a draft containing the tested IPA and checksum.
5. The source generator fetches published release metadata, downloads each recognized stable IPA over HTTPS, checks its size and checksum, and reads its actual Info.plist to verify app identity, version, build version, device platform, and minimum iOS version. It retries transient download errors and rejects HTTPS downgrade redirects. No source entry is created for a nonexistent, draft, or prerelease IPA.
6. The generated source contains the newest semantic version first, real release notes, app permissions, an original icon, and an actual simulator capture. The release workflow saves a separate source-bundle artifact. After the release succeeds, **Publish verified IPA source** downloads that exact run’s artifact, validates its public IPA downloads again, and deploys it to Pages. The final check compares the hosted JSON with the verified source bundle and downloads the hosted icon and screenshot.

Verified public locations:

- Releases: `https://github.com/naahs-lawragga/StreamHub-IOS/releases`
- Source: `https://naahs-lawragga.github.io/StreamHub-IOS/source.json`

The 0.1.2 release and source were independently verified after deployment on 2026-11-22; 0.1.1 remains in the verified version history. For later releases, check both workflow results and the public IPA/source URLs before recording publication as complete. The checked-in `source.template.json` contains no app version and is not a working app source. Versions 0.1.1 and later use the source URL above; release builds compute it from the repository name. The initial 0.1.0 development IPA has no configured source URL and requires manual updating.

The source follows [AltStore Classic's current source format](https://faq.altstore.io/developers/make-a-source), including versions with the actual IPA `buildVersion`, bundle identity, app permissions, and screenshots with dimensions read from the actual CI capture. The generator also emits `buildNumber` and `screenshotURLs` aliases because LiveContainer 3.8.0 reads those legacy names; each alias is validated against its canonical AltSource field. SideStore and AltStore use the canonical fields. It omits marketplace-only properties. LiveContainer 3.8.0 parser compatibility was checked in source code; real-device installation remains untested. `sha256` and `streamhubReleaseURL` are StreamHub extension fields; signing tools may ignore them. The unsigned app requests no app entitlements or privacy permissions. The privacy manifest's required-reason API declarations are separate from user-facing privacy usage permissions. Update source permissions if the app gains entitlements or protected-resource access.

## Recovery without replacing published IPAs

A failed Pages deployment does not remove the GitHub Release or the IPA workflow artifact. Fix Pages configuration, then rerun the failed deployment job. If the source generation job itself needs rerunning, manually dispatch the release workflow with the same approved tag.

A rerun preserves every already-published IPA/checksum and rebuilds the source from those verified public downloads. It refuses to fill missing assets into a published release; publish a new version for a corrected build. An unpublished draft may be repaired with the newly tested artifacts before publication. Original public binaries are never overwritten.

When dispatching from a newer main branch, the workflow definition comes from the selected dispatch ref while app source checks out the requested immutable tag. This was used for 0.1.1: workflow commit `7e0d9db` repaired the XcodeGen cache while the app remained at tagged commit `53d8366`. The cache now retains the tool’s source checkout and SettingPresets, and validates required preset files before project generation. To release newer app changes, create a new version tag rather than rerunning an old one.

## Pages deployment from the default branch

`Publish verified IPA source` is triggered only after the release workflow succeeds. It runs from the default branch so GitHub's default `github-pages` environment policy allowing `main` remains intact. It downloads that exact successful run's verified source artifact, revalidates public IPA checksums and identity/build metadata, deploys it, and checks the hosted JSON and artwork. It never executes files from the artifact. A failed release does not trigger a deployment. Repository owners only need to set Pages → Source to GitHub Actions; they do not need to permit version tags in the Pages environment.
