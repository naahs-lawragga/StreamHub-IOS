import Foundation

/// Documented by LiveContainer's Sources guide; LiveContainer 3.8.0 decodes the
/// `url` query item once. Encoding only RFC 3986 unreserved characters preserves
/// nested queries, plus signs, percent escapes, and fragments without ambiguity.
public enum SourceInstallationLink {
    public static func liveContainer(sourceURL: URL) -> URL? {
        guard UpdateFeed.isSecureURL(sourceURL) else { return nil }
        let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        guard let encoded = sourceURL.absoluteString.addingPercentEncoding(withAllowedCharacters: unreserved) else { return nil }
        return URL(string: "livecontainer://source?url=" + encoded)
    }
}
