import Foundation

/// All errors produced by `NoukaiSDK`. Covers key validation, networking,
/// decoding, and execution state errors.
public enum NoukaiError: Error, Sendable, Equatable {
    /// The API key was absent (keychain returned nothing).
    case noApiKey

    /// The key string does not match the expected `nk_live_` / `nk_test_` format.
    case invalidKeyFormat(String)

    /// The server rejected the key (HTTP 401 or 403).
    case keyRejected(String)

    /// The server returned a non-2xx status code.
    case httpError(statusCode: Int, body: String)

    /// The response body could not be decoded into the expected type.
    case decodingError(String)

    /// A transport-layer error (no connectivity, timeout, etc.).
    case networkError(String)

    /// `resume(with:)` was called but there is no stored paused execution state.
    case noResumeState
}
