import Foundation

/// Pure helpers for validating and masking noukai API keys.
///
/// Key format: `nk_live_<keyId>_<secret>` (production) or
///             `nk_test_<keyId>_<secret>` (development / test).
public enum ApiKeyFormat {

    // MARK: - Validation

    /// Validates that a key has the correct prefix format.
    ///
    /// - Parameters:
    ///   - key: The raw API key string to validate.
    ///   - allowTest: Pass `true` in debug builds to accept `nk_test_` keys.
    /// - Returns: `.success(())` if the format is valid;
    ///   `.failure(.invalidKeyFormat(...))` otherwise.
    public static func validate(_ key: String, allowTest: Bool) -> Result<Void, NoukaiError> {
        guard !key.isEmpty else {
            return .failure(.invalidKeyFormat("Key cannot be empty"))
        }
        if key.hasPrefix("nk_live_") { return .success(()) }
        if allowTest && key.hasPrefix("nk_test_") { return .success(()) }
        if key.hasPrefix("nk_test_") {
            return .failure(.invalidKeyFormat("Test keys are not allowed in production"))
        }
        return .failure(.invalidKeyFormat("Key must start with nk_live_"))
    }

    // MARK: - Masking

    /// Masks a key for safe display. Shows the prefix, the key-ID segment, and
    /// the last 6 characters of the secret.
    ///
    /// Example:
    /// ```
    /// "nk_live_Ab12CdEf_your32charsecrethere1234567890ab"
    /// → "nk_live_Ab12CdEf_…7890ab"
    /// ```
    ///
    /// If the key does not match the expected 3-segment structure, returns the
    /// first 12 characters followed by `…`. Never crashes; always returns
    /// something displayable.
    public static func mask(_ key: String) -> String {
        guard key.hasPrefix("nk_live_") || key.hasPrefix("nk_test_") else {
            return gracefulMask(key)
        }

        // Both prefixes are 8 characters: "nk_live_" / "nk_test_"
        let prefix = String(key.prefix(8))
        let remainder = String(key.dropFirst(8))

        // remainder should be "<keyId>_<secret>"
        guard let underscoreIdx = remainder.firstIndex(of: "_") else {
            return gracefulMask(key)
        }

        let keyId = String(remainder[remainder.startIndex..<underscoreIdx])
        let secret = String(remainder[remainder.index(after: underscoreIdx)...])

        guard secret.count >= 6 else {
            return gracefulMask(key)
        }

        let lastSix = String(secret.suffix(6))
        return "\(prefix)\(keyId)_\u{2026}\(lastSix)"
    }

    // MARK: - Private

    private static func gracefulMask(_ key: String) -> String {
        key.count <= 12 ? key : String(key.prefix(12)) + "\u{2026}"
    }
}
