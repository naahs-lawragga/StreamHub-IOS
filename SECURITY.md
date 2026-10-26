# Security policy

Only the latest stable release is intended to receive security fixes. No stable release has been published during initial development.

For suspected vulnerabilities, use GitHub's private vulnerability reporting feature if enabled under Security → Report a vulnerability. Otherwise request a private reporting channel from the maintainer without posting exploit details or credentials publicly. Include the version, affected component, impact, and minimal reproduction.

StreamHub uses public Apple APIs and HTTPS. It never requests an Apple Account password or installs applications silently. TMDB tokens belong in the app's local credential setting, never in Git or CI logs. Browser sessions may contain sensitive provider credentials; clearing website data signs you out. Do not share diagnostic data containing tokens or signed playback URLs.

Update sources must identify `com.streamhub.ios`, validate version/URL/size fields, and be hosted over HTTPS. IPA downloads are delegated to the selected installation tool. Release workflows publish SHA-256 checksums. Users must trust the signing tool and source owner. Never treat an unsigned IPA as directly installable on stock iOS.
