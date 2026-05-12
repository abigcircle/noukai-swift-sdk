import Testing
import Foundation
@testable import NoukaiSDK

@Suite("ApiKeyFormat")
struct ApiKeyFormatTests {

    // MARK: - validate

    @Test func validate_emptyKey_fails() {
        let result = ApiKeyFormat.validate("", allowTest: false)
        guard case .failure(.invalidKeyFormat(let msg)) = result else {
            Issue.record("Expected invalidKeyFormat, got \(result)")
            return
        }
        #expect(msg.contains("empty"))
    }

    @Test func validate_liveKey_succeeds() {
        let result = ApiKeyFormat.validate("nk_live_Ab12_secret", allowTest: false)
        guard case .success = result else {
            Issue.record("Expected success, got \(result)")
            return
        }
    }

    @Test func validate_testKey_inProd_fails() {
        let result = ApiKeyFormat.validate("nk_test_Ab12_secret", allowTest: false)
        guard case .failure(.invalidKeyFormat(let msg)) = result else {
            Issue.record("Expected invalidKeyFormat, got \(result)")
            return
        }
        #expect(msg.contains("production"))
    }

    @Test func validate_testKey_allowTest_succeeds() {
        let result = ApiKeyFormat.validate("nk_test_Ab12_secret", allowTest: true)
        guard case .success = result else {
            Issue.record("Expected success, got \(result)")
            return
        }
    }

    @Test func validate_wrongPrefix_fails() {
        let result = ApiKeyFormat.validate("sk_live_Ab12_secret", allowTest: false)
        guard case .failure(.invalidKeyFormat(let msg)) = result else {
            Issue.record("Expected invalidKeyFormat, got \(result)")
            return
        }
        #expect(msg.contains("nk_live_"))
    }

    // MARK: - mask

    @Test func mask_liveKey_showsKeyIdAndLastSix() {
        let key = "nk_live_Ab12CdEf_your32charsecrethere1234567890ab"
        let masked = ApiKeyFormat.mask(key)
        #expect(masked == "nk_live_Ab12CdEf_…7890ab")
    }

    @Test func mask_testKey_showsKeyIdAndLastSix() {
        let key = "nk_test_Ab12CdEf_your32charsecrethere1234567890ab"
        let masked = ApiKeyFormat.mask(key)
        #expect(masked == "nk_test_Ab12CdEf_…7890ab")
    }

    @Test func mask_shortKey_returnsGraceful() {
        let key = "short"
        let masked = ApiKeyFormat.mask(key)
        #expect(masked == "short")
    }

    @Test func mask_longUnknownPrefix_truncatesTo12() {
        // "unknownprefix" is 13 chars; prefix(12) = "unknownprefi"
        let key = "unknownprefix_this_is_long_enough_to_be_truncated"
        let masked = ApiKeyFormat.mask(key)
        #expect(masked == "unknownprefi…")
    }

    @Test func mask_noSecondUnderscore_returnsGraceful() {
        let key = "nk_live_nounderscore"
        let masked = ApiKeyFormat.mask(key)
        // No second underscore — falls back to graceful mask
        #expect(masked.contains("…") || masked == key)
    }

    @Test func mask_shortSecret_returnsGraceful() {
        let key = "nk_live_Ab12_abc"
        let masked = ApiKeyFormat.mask(key)
        // secret "abc" is 3 chars < 6, falls back to graceful mask
        #expect(masked.contains("…") || masked.hasPrefix("nk_live_Ab12"))
    }
}
