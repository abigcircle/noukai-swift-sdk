/// All tests that use `MockURLProtocol` live in this single serialized suite.
/// Swift Testing runs top-level suites concurrently; since `MockURLProtocol`
/// uses shared static state, all consumers must serialize.
import Testing
import Foundation
@testable import NoukaiSDK

private func fixtureData(_ name: String) throws -> Data {
    let url = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "Fixtures"
    )!
    return try Data(contentsOf: url)
}

private func makeConfig(
    org: String = "acme",
    project: String = "po",
    flow: String = "agent-loop",
    version: Int? = nil
) -> NoukaiConfiguration {
    NoukaiConfiguration(
        baseURL: URL(string: "https://api.noukai.xyz")!,
        org: org,
        project: project,
        flow: flow,
        version: version
    )
}

private func makeClient(config: NoukaiConfiguration? = nil) -> NoukaiClient {
    NoukaiClient(
        configuration: config ?? makeConfig(),
        session: MockURLProtocol.session()
    )
}

private let validKey = "nk_live_Ab12_secretsecretsecretsecret"

@Suite(.serialized)
struct NoukaiClientTests {

    // MARK: - execute: correct URL

    @Test func execute_sendsToConfiguredURL() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.responseData = try fixtureData("execute-completed")
        MockURLProtocol.responseStatusCode = 200

        let config = makeConfig(org: "myorg", project: "myproj", flow: "myflow")
        let client = makeClient(config: config)
        let request = ExecutionRequest(message: "hi", apiKey: validKey)
        _ = try await client.execute(request)

        let req = MockURLProtocol.lastRequest!
        #expect(req.url?.absoluteString ==
            "https://api.noukai.xyz/api/v1/seq/myorg/myproj/myflow/execute")
    }

    @Test func execute_withVersion_appendsQueryParam() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.responseData = try fixtureData("execute-completed")
        MockURLProtocol.responseStatusCode = 200

        let config = makeConfig(version: 5)
        let client = makeClient(config: config)
        _ = try await client.execute(ExecutionRequest(message: "hi", apiKey: validKey))

        let url = MockURLProtocol.lastRequest?.url?.absoluteString ?? ""
        #expect(url.contains("version=5"))
    }

    // MARK: - execute: correct headers

    @Test func execute_setsAuthorizationHeader() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.responseData = try fixtureData("execute-completed")
        MockURLProtocol.responseStatusCode = 200

        let client = makeClient()
        _ = try await client.execute(ExecutionRequest(message: "hi", apiKey: validKey))

        let req = MockURLProtocol.lastRequest!
        #expect(req.value(forHTTPHeaderField: "Authorization") == "Bearer \(validKey)")
    }

    @Test func execute_setsContentTypeHeader() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.responseData = try fixtureData("execute-completed")
        MockURLProtocol.responseStatusCode = 200

        let client = makeClient()
        _ = try await client.execute(ExecutionRequest(message: "hi", apiKey: validKey))

        #expect(MockURLProtocol.lastRequest?.value(forHTTPHeaderField: "Content-Type") ==
            "application/json")
    }

    @Test func execute_setsUserAgentHeader() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.responseData = try fixtureData("execute-completed")
        MockURLProtocol.responseStatusCode = 200

        let client = makeClient()
        _ = try await client.execute(ExecutionRequest(message: "hi", apiKey: validKey))

        #expect(MockURLProtocol.lastRequest?.value(forHTTPHeaderField: "User-Agent") ==
            "NoukaiSDK/1.0")
    }

    @Test func execute_usesPostMethod() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.responseData = try fixtureData("execute-completed")
        MockURLProtocol.responseStatusCode = 200

        let client = makeClient()
        _ = try await client.execute(ExecutionRequest(message: "hi", apiKey: validKey))

        #expect(MockURLProtocol.lastRequest?.httpMethod == "POST")
    }

    // MARK: - execute: request body

    @Test func execute_bodyContainsMessage() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.responseData = try fixtureData("execute-completed")
        MockURLProtocol.responseStatusCode = 200

        let client = makeClient()
        _ = try await client.execute(ExecutionRequest(message: "hello world", apiKey: validKey))

        let body = try JSONSerialization.jsonObject(
            with: MockURLProtocol.lastRequest!.httpBody!
        ) as! [String: Any]
        #expect(body["message"] as? String == "hello world")
        // Initial execute must NOT have executionId
        #expect(body["executionId"] == nil)
    }

    @Test func execute_withTools_bodyContainsTools() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.responseData = try fixtureData("execute-completed")
        MockURLProtocol.responseStatusCode = 200

        let tool = ToolSpec(
            name: "list_tasks",
            description: "List tasks",
            parameters: .object(["limit": .int(10)])
        )
        let client = makeClient()
        let req = ExecutionRequest(
            message: "list tasks",
            apiKey: validKey,
            tools: [tool],
            toolChoice: "auto"
        )
        _ = try await client.execute(req)

        let body = try JSONSerialization.jsonObject(
            with: MockURLProtocol.lastRequest!.httpBody!
        ) as! [String: Any]
        #expect(body["toolChoice"] as? String == "auto")
        let tools = body["tools"] as? [[String: Any]]
        #expect(tools?.count == 1)
    }

    @Test func execute_withParameters_bodyContainsParameters() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.responseData = try fixtureData("execute-completed")
        MockURLProtocol.responseStatusCode = 200

        let client = makeClient()
        let req = ExecutionRequest(
            message: "hi",
            apiKey: validKey,
            parameters: ["context": .string("my context")]
        )
        _ = try await client.execute(req)

        let body = try JSONSerialization.jsonObject(
            with: MockURLProtocol.lastRequest!.httpBody!
        ) as! [String: Any]
        let params = body["parameters"] as? [String: Any]
        #expect(params?["context"] as? String == "my context")
    }

    // MARK: - execute: response parsing

    @Test func execute_completed_returnsCompletedStatus() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.responseData = try fixtureData("execute-completed")
        MockURLProtocol.responseStatusCode = 200

        let client = makeClient()
        let response = try await client.execute(ExecutionRequest(message: "hi", apiKey: validKey))
        #expect(response.status == .completed)
    }

    @Test func execute_toolCalls_returnsToolCallsRequiredStatus() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.responseData = try fixtureData("execute-tool-calls")
        MockURLProtocol.responseStatusCode = 200

        let client = makeClient()
        let response = try await client.execute(ExecutionRequest(message: "find billing", apiKey: validKey))
        #expect(response.status == .toolCallsRequired)
        #expect(response.executionId == "exec_abc")
    }

    @Test func execute_toolCallsRequired_storesResumeState() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.responseData = try fixtureData("execute-tool-calls")
        MockURLProtocol.responseStatusCode = 200

        let client = makeClient()
        _ = try await client.execute(ExecutionRequest(message: "find billing", apiKey: validKey))

        // Now resume should succeed (resume state was stored)
        MockURLProtocol.reset()
        MockURLProtocol.responseData = try fixtureData("execute-completed")
        MockURLProtocol.responseStatusCode = 200

        do {
            _ = try await client.resume(
                with: [ToolResult(toolCallId: "call_1", content: "[{\"id\":\"t1\"}]")],
                apiKey: validKey
            )
            // Reached here — no error thrown, which is what we expect.
        } catch let error as NoukaiError {
            if case .noResumeState = error {
                Issue.record("Resume state should have been stored after tool_calls_required response")
            }
            // Other errors (HTTP, decode) are acceptable in this path since we just need
            // to verify that resume state was carried across.
        }
    }

    // MARK: - resume

    @Test func resume_noState_throwsNoResumeState() async {
        MockURLProtocol.reset()
        let client = makeClient()

        do {
            _ = try await client.resume(
                with: [ToolResult(toolCallId: "x", content: "y")],
                apiKey: validKey
            )
            Issue.record("Expected noResumeState error")
        } catch let error as NoukaiError {
            #expect(error == .noResumeState)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test func resume_sendsResumeBody() async throws {
        // First call — get tool-calls response
        MockURLProtocol.reset()
        MockURLProtocol.responseData = try fixtureData("execute-tool-calls")
        MockURLProtocol.responseStatusCode = 200

        let client = makeClient()
        _ = try await client.execute(ExecutionRequest(message: "find billing", apiKey: validKey))

        // Second call — resume
        MockURLProtocol.reset()
        MockURLProtocol.responseData = try fixtureData("execute-completed")
        MockURLProtocol.responseStatusCode = 200

        _ = try await client.resume(
            with: [ToolResult(toolCallId: "call_1", content: "result text")],
            apiKey: validKey
        )

        let body = try JSONSerialization.jsonObject(
            with: MockURLProtocol.lastRequest!.httpBody!
        ) as! [String: Any]
        // Resume body must have executionId
        #expect(body["executionId"] as? String == "exec_abc")
        #expect(body["pausedAtStep"] as? String == "step_2")
        #expect(body["iterationsUsed"] as? Int == 1)

        // toolCallMessages should be an array containing original messages + tool result
        let msgs = body["toolCallMessages"] as? [[String: Any]]
        #expect(msgs != nil)
        // The appended tool result must be the last element
        let lastMsg = msgs?.last
        #expect(lastMsg?["role"] as? String == "tool")
        #expect(lastMsg?["tool_call_id"] as? String == "call_1")
        #expect(lastMsg?["content"] as? String == "result text")
    }

    // MARK: - resetExecution

    @Test func resetExecution_clearsResumeState() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.responseData = try fixtureData("execute-tool-calls")
        MockURLProtocol.responseStatusCode = 200

        let client = makeClient()
        _ = try await client.execute(ExecutionRequest(message: "find billing", apiKey: validKey))

        await client.resetExecution()

        do {
            _ = try await client.resume(
                with: [ToolResult(toolCallId: "x", content: "y")],
                apiKey: validKey
            )
            Issue.record("Expected noResumeState after reset")
        } catch let error as NoukaiError {
            #expect(error == .noResumeState)
        }
    }

    // MARK: - Error paths

    @Test func execute_httpError_throwsHttpError() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.responseStatusCode = 500
        MockURLProtocol.responseData = "Internal Server Error".data(using: .utf8)!

        let client = makeClient()
        do {
            _ = try await client.execute(ExecutionRequest(message: "hi", apiKey: validKey))
            Issue.record("Expected httpError")
        } catch let error as NoukaiError {
            guard case .httpError(let status, _) = error else {
                Issue.record("Expected httpError, got \(error)")
                return
            }
            #expect(status == 500)
        }
    }

    @Test func execute_401_throwsHttpError() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.responseStatusCode = 401
        MockURLProtocol.responseData = #"{"error":"unauthorized"}"#.data(using: .utf8)!

        let client = makeClient()
        do {
            _ = try await client.execute(ExecutionRequest(message: "hi", apiKey: validKey))
            Issue.record("Expected httpError")
        } catch let error as NoukaiError {
            guard case .httpError(let status, let body) = error else {
                Issue.record("Expected httpError, got \(error)")
                return
            }
            #expect(status == 401)
            #expect(body.contains("unauthorized"))
        }
    }

    @Test func execute_networkFailure_throwsNetworkError() async {
        MockURLProtocol.reset()
        MockURLProtocol.responseError = URLError(.notConnectedToInternet)

        let client = makeClient()
        do {
            _ = try await client.execute(ExecutionRequest(message: "hi", apiKey: validKey))
            Issue.record("Expected networkError")
        } catch let error as NoukaiError {
            guard case .networkError = error else {
                Issue.record("Expected networkError, got \(error)")
                return
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test func execute_malformedResponse_throwsDecodingError() async {
        MockURLProtocol.reset()
        MockURLProtocol.responseStatusCode = 200
        MockURLProtocol.responseData = #"{"not":"a valid response"}"#.data(using: .utf8)!

        let client = makeClient()
        do {
            _ = try await client.execute(ExecutionRequest(message: "hi", apiKey: validKey))
            Issue.record("Expected decodingError")
        } catch let error as NoukaiError {
            guard case .decodingError = error else {
                Issue.record("Expected decodingError, got \(error)")
                return
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test func execute_emptyBody200_throwsDecodingError() async {
        MockURLProtocol.reset()
        MockURLProtocol.responseStatusCode = 200
        MockURLProtocol.responseData = Data()

        let client = makeClient()
        do {
            _ = try await client.execute(ExecutionRequest(message: "hi", apiKey: validKey))
            Issue.record("Expected decodingError")
        } catch let error as NoukaiError {
            guard case .decodingError = error else {
                Issue.record("Expected decodingError, got \(error)")
                return
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    // MARK: - validateKey

    @Test func validateKey_emptyKey_returnsInvalidFormat() async {
        MockURLProtocol.reset()
        let client = makeClient()
        let result = await client.validateKey("")
        guard case .failure(.invalidKeyFormat) = result else {
            Issue.record("Expected invalidKeyFormat, got \(result)")
            return
        }
        #expect(MockURLProtocol.lastRequest == nil)
    }

    @Test func validateKey_200_returnsSuccess() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.responseStatusCode = 200
        MockURLProtocol.responseData = #"{"ok":true}"#.data(using: .utf8)!

        let client = makeClient()
        let result = await client.validateKey(validKey)
        guard case .success = result else {
            Issue.record("Expected success, got \(result)")
            return
        }
    }

    @Test func validateKey_401_returnsKeyRejected() async {
        MockURLProtocol.reset()
        MockURLProtocol.responseStatusCode = 401
        MockURLProtocol.responseData = #"{"error":"invalid key"}"#.data(using: .utf8)!

        let client = makeClient()
        let result = await client.validateKey(validKey)
        guard case .failure(.keyRejected(let reason)) = result else {
            Issue.record("Expected keyRejected, got \(result)")
            return
        }
        #expect(reason.contains("rejected"))
    }

    @Test func validateKey_403_returnsKeyRejected() async {
        MockURLProtocol.reset()
        MockURLProtocol.responseStatusCode = 403
        MockURLProtocol.responseData = Data()

        let client = makeClient()
        let result = await client.validateKey(validKey)
        guard case .failure(.keyRejected) = result else {
            Issue.record("Expected keyRejected, got \(result)")
            return
        }
    }

    @Test func validateKey_500_returnsNetworkError() async {
        MockURLProtocol.reset()
        MockURLProtocol.responseStatusCode = 500
        MockURLProtocol.responseData = Data()

        let client = makeClient()
        let result = await client.validateKey(validKey)
        guard case .failure(.networkError) = result else {
            Issue.record("Expected networkError, got \(result)")
            return
        }
    }

    @Test func validateKey_networkFailure_returnsNetworkError() async {
        MockURLProtocol.reset()
        MockURLProtocol.responseError = URLError(.notConnectedToInternet)

        let client = makeClient()
        let result = await client.validateKey(validKey)
        guard case .failure(.networkError) = result else {
            Issue.record("Expected networkError, got \(result)")
            return
        }
    }

    @Test func validateKey_testKey_allowTest_probesServer() async {
        MockURLProtocol.reset()
        MockURLProtocol.responseStatusCode = 200
        MockURLProtocol.responseData = "{}".data(using: .utf8)!

        let client = makeClient()
        let result = await client.validateKey("nk_test_Ab12_secretsecret", allowTest: true)
        guard case .success = result else {
            Issue.record("Expected success, got \(result)")
            return
        }
        #expect(MockURLProtocol.lastRequest != nil)
    }

    @Test func validateKey_testKey_prodMode_returnsInvalidFormat() async {
        MockURLProtocol.reset()
        let client = makeClient()
        let result = await client.validateKey("nk_test_Ab12_secretsecret", allowTest: false)
        guard case .failure(.invalidKeyFormat) = result else {
            Issue.record("Expected invalidKeyFormat, got \(result)")
            return
        }
        #expect(MockURLProtocol.lastRequest == nil)
    }

    @Test func validateKey_setsCorrectHeaders() async {
        MockURLProtocol.reset()
        MockURLProtocol.responseStatusCode = 200
        MockURLProtocol.responseData = "{}".data(using: .utf8)!

        let client = makeClient()
        _ = await client.validateKey(validKey)

        let req = MockURLProtocol.lastRequest!
        #expect(req.value(forHTTPHeaderField: "Authorization") == "Bearer \(validKey)")
        #expect(req.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(req.value(forHTTPHeaderField: "User-Agent") == "NoukaiSDK/1.0")
        #expect(req.httpMethod == "POST")
    }

    @Test func validateKey_sendsPingBody() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.responseStatusCode = 200
        MockURLProtocol.responseData = "{}".data(using: .utf8)!

        let client = makeClient()
        _ = await client.validateKey(validKey)

        let body = try JSONSerialization.jsonObject(
            with: MockURLProtocol.lastRequest!.httpBody!
        ) as! [String: Any]
        #expect(body["message"] as? String == "ping")
    }
}

