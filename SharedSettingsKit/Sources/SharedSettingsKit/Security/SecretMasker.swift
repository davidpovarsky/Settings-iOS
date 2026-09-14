import Foundation

/// Safe utility for displaying masked previews of secret credentials without leaking raw secrets.
public enum SecretMasker {
    /// Returns a secure masked representation of a credential string.
    ///
    /// - Parameters:
    ///   - secret: The raw secret string.
    ///   - visiblePrefix: Number of leading characters to keep visible (default: 3).
    ///   - visibleSuffix: Number of trailing characters to keep visible (default: 4).
    /// - Returns: A masked string such as `"sk-••••••••abcd"` or `"••••••••••••"`.
    public static func mask(
        _ secret: String,
        visiblePrefix: Int = 3,
        visibleSuffix: Int = 4
    ) -> String {
        guard !secret.isEmpty else { return "" }

        let count = secret.count
        if count <= (visiblePrefix + visibleSuffix + 4) {
            // Secret is too short to show partial plaintext safely.
            return String(repeating: "•", count: min(count, 12))
        }

        let prefixEnd = secret.index(secret.startIndex, offsetBy: visiblePrefix)
        let suffixStart = secret.index(secret.endIndex, offsetBy: -visibleSuffix)

        let prefix = String(secret[..<prefixEnd])
        let suffix = String(secret[suffixStart...])
        let bullets = String(repeating: "•", count: 8)

        return "\(prefix)\(bullets)\(suffix)"
    }

    /// Fully masks the entire secret string with bullets.
    public static func fullMask(_ secret: String, count: Int = 12) -> String {
        guard !secret.isEmpty else { return "" }
        return String(repeating: "•", count: count)
    }
}
