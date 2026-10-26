# Approved releases and public IPA source

Normal main-branch builds never publish a stable release. `release.yml` only responds to version tags and is disabled unless the repository variable `STREAMHUB_RELEASES_ENABLED` is exactly `true`.

Before enabling releases, the repository owner must approve publication, configure a `release` GitHub Environment with required reviewers and protected version tags, and enable Pages using GitHub Actions as its source. Reviewers must verify device-test evidence appropriate for the release, licenses, credentials, and the intended tag. GitHub Environment review is a repository setting; merely declaring the environment in YAML does not add reviewers.

1. Finish and review the change on main. Run the build workflow and inspect its actual results.
2. Update version/changelog documentation. Select a stable semantic version `major.minor.patch`; prerelease tags are rejected by this stable workflow.
3. With release authorization, create a signed or annotated `vX.Y.Z` tag pointing to an approved commit reachable from main. Push that tag. Do not force-update a published tag.
4. Approve the protected `release` environment. The workflow rebuilds and tests, validates the device bundle, computes SHA-256, and creates a draft containing the IPA and checksum. Only successful jobs publish it.
5. The generator fetches published release metadata, downloads each recognized stable IPA over HTTPS, verifies its size and checksum, and writes a source with the newest semantic version first. Missing/draft/prerelease assets are excluded; malformed assets fail publication.
6. Pages deploys the generated source and original icon plus actual simulator capture. The final step retrieves the hosted JSON and checks the app identity.

After success, the default locations are:

- Releases: `https://github.com/OWNER/StreamHub-iOS/releases`
- Source: `https://OWNER.github.io/StreamHub-iOS/source.json`

These are URL patterns, not claims that anything has been deployed. This checkout initially has no published source entry and no stable release. The checked-in `source.template.json` has an empty app list; it must not be advertised as a working app source. Release builds embed their repository's computed Pages source URL. Development artifacts leave automatic source checking unconfigured unless explicitly set.

The source follows [AltStore Classic's current source format](https://faq.altstore.io/developers/make-a-source), including versions, bundle identity, app permissions, and optional screenshots. It omits marketplace-only properties. `sha256` and `streamhubReleaseURL` are StreamHub extension fields; signing tools may ignore them. No privacy permissions or app entitlements are requested by the unsigned app. If either changes, update the source generator and review its permission declarations against the built IPA.

If Pages fails after GitHub Release publication, the existing source remains unchanged. Fix the deployment and rerun the failed deployment job; never add an entry to a failed or nonexistent IPA. If artifact/source verification fails, investigate before retrying. Do not overwrite a previously published release's IPA; issue a new version for corrected builds.
