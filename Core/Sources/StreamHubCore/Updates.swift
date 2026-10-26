import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// SemVer 2.0 precedence. Build metadata does not affect precedence.
public struct SemanticVersion: Comparable, Hashable, Sendable {
    public let major: Int
    public let minor: Int
    public let patch: Int
    public let prerelease: [String]

    public init?(_ value: String) {
        let parts = value.split(separator: "+", omittingEmptySubsequences: false)
        guard parts.count <= 2 else { return nil }
        if parts.count == 2, !Self.validIdentifiers(String(parts[1]), numericLeadingZeroAllowed: true) { return nil }
        let base = parts[0].split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        let numbers = base[0].split(separator: ".", omittingEmptySubsequences: false)
        guard numbers.count == 3,
              numbers.allSatisfy({ Self.isDigits(String($0)) && ($0.count == 1 || $0.first != "0") }),
              let major = Int(numbers[0]), let minor = Int(numbers[1]), let patch = Int(numbers[2]) else { return nil }
        if base.count == 2, !Self.validIdentifiers(String(base[1]), numericLeadingZeroAllowed: false) { return nil }
        self.major = major; self.minor = minor; self.patch = patch
        self.prerelease = base.count == 2 ? base[1].split(separator: ".").map(String.init) : []
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        if lhs.patch != rhs.patch { return lhs.patch < rhs.patch }
        if lhs.prerelease.isEmpty { return false }
        if rhs.prerelease.isEmpty { return true }
        for (left, right) in zip(lhs.prerelease, rhs.prerelease) where left != right {
            let ln = isDigits(left), rn = isDigits(right)
            if ln && rn { return left.count == right.count ? left < right : left.count < right.count }
            if ln != rn { return ln }
            return left < right
        }
        return lhs.prerelease.count < rhs.prerelease.count
    }

    private static func isDigits(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.allSatisfy { (48...57).contains($0) }
    }

    private static func validIdentifiers(_ value: String, numericLeadingZeroAllowed: Bool) -> Bool {
        value.split(separator: ".", omittingEmptySubsequences: false).allSatisfy { part in
            !part.isEmpty && part.utf8.allSatisfy { (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 45 }
            && (numericLeadingZeroAllowed || !isDigits(String(part)) || part.count == 1 || part.first != "0")
        }
    }
}

public struct UpdateRelease: Codable, Hashable, Identifiable, Sendable {
    public var id: String { version }
    public let version: String
    public let buildVersion: String?
    public let date: String
    public let localizedDescription: String?
    public let downloadURL: URL
    public let size: Int64
    public let minOSVersion: String?
    public let maxOSVersion: String?
    /// StreamHub-specific optional metadata. It is advisory and never locks the app.
    public let streamhubSecurityUpdate: Bool?
    public let streamhubReleaseURL: URL?
    public let sha256: String?
}

public enum UpdateError: LocalizedError {
    case insecureURL, invalidMetadata(String), wrongIdentity, server(Int), noPublishedVersion
    public var errorDescription: String? {
        switch self {
        case .insecureURL: return "Update links must use HTTPS without embedded credentials."
        case .invalidMetadata(let detail): return "The update source is invalid: \(detail)"
        case .wrongIdentity: return "The update source does not identify this application."
        case .server(let code): return "The update server returned HTTP \(code). Try again later."
        case .noPublishedVersion: return "No compatible stable version has been published yet."
        }
    }
}

public enum UpdateFeed {
    private struct Source: Decodable { let name: String; let apps: [AppEntry] }
    private struct AppEntry: Decodable { let bundleIdentifier: String; let versions: [UpdateRelease] }

    public static func isSecureURL(_ url: URL) -> Bool {
        url.scheme?.lowercased() == "https" && !(url.host ?? "").isEmpty && url.user == nil && url.password == nil
    }

    /// Reads the official AltSource `apps[].versions[]` shape. No fabricated fallback release.
    public static func latest(in data: Data, expectedBundleID: String = "com.streamhub.ios", operatingSystem: String = "17.0") throws -> UpdateRelease {
        guard data.count <= 2_000_000 else { throw UpdateError.invalidMetadata("response exceeds 2 MB") }
        let source: Source
        do { source = try JSONDecoder().decode(Source.self, from: data) }
        catch { throw UpdateError.invalidMetadata("missing or incorrectly typed fields") }
        guard !source.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw UpdateError.invalidMetadata("missing source name") }
        let matching = source.apps.filter { $0.bundleIdentifier == expectedBundleID }
        guard matching.count == 1 else { throw UpdateError.wrongIdentity }
        var releases: [(SemanticVersion, UpdateRelease)] = []
        var versions = Set<String>()
        for release in matching[0].versions {
            guard let semantic = SemanticVersion(release.version), release.size > 0,
                  validDate(release.date), (release.localizedDescription?.count ?? 0) <= 100_000,
                  versions.insert(release.version).inserted else { throw UpdateError.invalidMetadata("invalid version, date, size, or duplicate release") }
            guard isSecureURL(release.downloadURL), release.downloadURL.pathExtension.lowercased() == "ipa",
                  release.streamhubReleaseURL.map(isSecureURL) ?? true else { throw UpdateError.insecureURL }
            if let checksum = release.sha256 {
                guard checksum.count == 64 && checksum.utf8.allSatisfy({ (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0) }) else { throw UpdateError.invalidMetadata("invalid SHA-256") }
            }
            let os = try osVersion(operatingSystem)
            let minimum = try release.minOSVersion.map(osVersion)
            let maximum = try release.maxOSVersion.map(osVersion)
            if let minimum, let maximum, maximum.lexicographicallyPrecedes(minimum) { throw UpdateError.invalidMetadata("inverted OS version range") }
            if let minimum, os.lexicographicallyPrecedes(minimum) { continue }
            if let maximum, maximum.lexicographicallyPrecedes(os) { continue }
            if semantic.prerelease.isEmpty { releases.append((semantic, release)) }
        }
        guard let latest = releases.max(by: { $0.0 < $1.0 })?.1 else { throw UpdateError.noPublishedVersion }
        return latest
    }

    public static func isNewer(_ release: UpdateRelease, than installed: String) -> Bool {
        guard let available = SemanticVersion(release.version), let current = SemanticVersion(installed) else { return false }
        return available > current
    }

    private static func osVersion(_ value: String) throws -> [Int] {
        let components = value.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...3).contains(components.count), components.allSatisfy({ !$0.isEmpty && $0.utf8.allSatisfy { (48...57).contains($0) } }),
              components.compactMap({ Int($0) }).count == components.count else { throw UpdateError.invalidMetadata("invalid OS version") }
        return components.compactMap { Int($0) } + Array(repeating: 0, count: 3 - components.count)
    }

    private static func validDate(_ value: String) -> Bool {
        let formatter = ISO8601DateFormatter()
        if formatter.date(from: value) != nil { return true }
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if formatter.date(from: value) != nil { return true }
        let day = DateFormatter()
        day.calendar = Calendar(identifier: .gregorian); day.locale = Locale(identifier: "en_US_POSIX")
        day.timeZone = TimeZone(secondsFromGMT: 0); day.dateFormat = "yyyy-MM-dd"; day.isLenient = false
        guard let date = day.date(from: value) else { return false }
        return day.string(from: date) == value
    }
}

/// Keeps the network boundary injectable for tests. Cache ownership stays with the calling UI.
public actor UpdateClient {
    private let session: URLSession
    public init(session: URLSession = .shared) { self.session = session }
    public func fetch(sourceURL: URL, expectedBundleID: String = "com.streamhub.ios", operatingSystem: String) async throws -> Data {
        guard UpdateFeed.isSecureURL(sourceURL) else { throw UpdateError.insecureURL }
        var request = URLRequest(url: sourceURL)
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse else { throw UpdateError.invalidMetadata("not an HTTP response") }
        guard let finalURL = http.url, UpdateFeed.isSecureURL(finalURL) else { throw UpdateError.insecureURL }
        guard (200..<300).contains(http.statusCode) else { throw UpdateError.server(http.statusCode) }
        _ = try UpdateFeed.latest(in: data, expectedBundleID: expectedBundleID, operatingSystem: operatingSystem)
        return data
    }
}

public struct UpdateReminderPolicy: Sendable {
    public static let automaticInterval: TimeInterval = 6 * 60 * 60
    public static func shouldCheck(lastAttempt: Date?, now: Date = Date()) -> Bool {
        guard let lastAttempt else { return true }
        return now.timeIntervalSince(lastAttempt) >= automaticInterval || now < lastAttempt
    }
    public static func shouldPresent(version: String, dismissedVersions: Set<String>) -> Bool { !dismissedVersions.contains(version) }
}
