import Testing
import Foundation
@testable import NoukaiSDK

@Suite("NoukaiConfiguration")
struct NoukaiConfigurationTests {

    private let base = URL(string: "https://api.noukai.xyz")!

    @Test func executeURL_basicPath() {
        let config = NoukaiConfiguration(
            baseURL: base,
            org: "myorg",
            project: "myproj",
            flow: "myflow"
        )
        #expect(config.executeURL.absoluteString ==
            "https://api.noukai.xyz/api/v1/seq/myorg/myproj/myflow/execute")
    }

    @Test func executeURL_withVersion_appendsQueryParam() {
        let config = NoukaiConfiguration(
            baseURL: base,
            org: "acme",
            project: "po",
            flow: "agent-loop",
            version: 3
        )
        let url = config.executeURL.absoluteString
        #expect(url.contains("/api/v1/seq/acme/po/agent-loop/execute"))
        #expect(url.contains("version=3"))
    }

    @Test func executeURL_noVersion_noQueryParam() {
        let config = NoukaiConfiguration(
            baseURL: base,
            org: "acme",
            project: "po",
            flow: "agent-loop"
        )
        #expect(!config.executeURL.absoluteString.contains("version"))
        #expect(!config.executeURL.absoluteString.contains("?"))
    }

    @Test func executeURL_defaultProjectAndFlow() {
        let config = NoukaiConfiguration(baseURL: base, org: "abc")
        #expect(config.executeURL.absoluteString ==
            "https://api.noukai.xyz/api/v1/seq/abc/po/agent-loop/execute")
    }

    @Test func equatable_sameValues_areEqual() {
        let a = NoukaiConfiguration(baseURL: base, org: "x", project: "y", flow: "z", version: 1)
        let b = NoukaiConfiguration(baseURL: base, org: "x", project: "y", flow: "z", version: 1)
        #expect(a == b)
    }

    @Test func equatable_differentVersion_notEqual() {
        let a = NoukaiConfiguration(baseURL: base, org: "x", project: "y", flow: "z", version: 1)
        let b = NoukaiConfiguration(baseURL: base, org: "x", project: "y", flow: "z", version: 2)
        #expect(a != b)
    }
}
