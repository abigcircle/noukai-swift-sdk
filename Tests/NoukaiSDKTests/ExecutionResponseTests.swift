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

@Suite("ExecutionResponse")
struct ExecutionResponseTests {

    // MARK: - Fixture-based parsing

    @Test func parse_completed_fixture() throws {
        let data = try fixtureData("execute-completed")
        let response = try JSONDecoder().decode(ExecutionResponse.self, from: data)
        #expect(response.status == .completed)
        #expect(response.flowId == "flow_123")
        #expect(response.blockCount == 3)
        if case .string(let text) = response.result {
            #expect(text.contains("2 tasks"))
        } else {
            Issue.record("Expected string result, got \(String(describing: response.result))")
        }
    }

    @Test func parse_toolCalls_fixture() throws {
        let data = try fixtureData("execute-tool-calls")
        let response = try JSONDecoder().decode(ExecutionResponse.self, from: data)
        #expect(response.status == .toolCallsRequired)
        #expect(response.executionId == "exec_abc")
        #expect(response.pausedAtStep == "step_2")
        #expect(response.iterationsUsed == 1)
        #expect(response.toolCallMessages?.count == 2)

        let assistantMsg = response.toolCallMessages?.last(where: { $0.role == "assistant" })
        #expect(assistantMsg != nil)
        #expect(assistantMsg?.toolCalls?.count == 1)
        #expect(assistantMsg?.toolCalls?.first?.function.name == "search_tasks")
        #expect(assistantMsg?.toolCalls?.first?.id == "call_1")
    }

    @Test func parse_failed_fixture() throws {
        let data = try fixtureData("execute-failed")
        let response = try JSONDecoder().decode(ExecutionResponse.self, from: data)
        #expect(response.status == .failed)
        if case .string(let text) = response.result {
            #expect(text.contains("timeout"))
        } else {
            Issue.record("Expected string result")
        }
    }

    @Test func parse_mixed_fixture() throws {
        let data = try fixtureData("execute-mixed")
        let response = try JSONDecoder().decode(ExecutionResponse.self, from: data)
        #expect(response.status == .toolCallsRequired)
        let assistant = response.toolCallMessages?.last(where: { $0.role == "assistant" })
        #expect(assistant?.textContent == "I'll close task #5 for you.")
        #expect(assistant?.toolCalls?.first?.function.name == "close_task")
    }

    // MARK: - Inline JSON

    @Test func parse_nullResult_isAllowed() throws {
        let raw = #"{"status":"completed","result":null,"flowId":"f_x","blockCount":1}"#
            .data(using: .utf8)!
        let response = try JSONDecoder().decode(ExecutionResponse.self, from: raw)
        #expect(response.status == .completed)
        #expect(response.result == nil)
    }

    @Test func parse_missingStatus_throws() {
        let raw = #"{"result":"ok"}"#.data(using: .utf8)!
        #expect(throws: (any Error).self) {
            _ = try JSONDecoder().decode(ExecutionResponse.self, from: raw)
        }
    }

    @Test func parse_toolCall_arguments_areParseable() throws {
        let raw = """
        {
            "status": "tool_calls_required",
            "executionId": "e1",
            "pausedAtStep": "s1",
            "iterationsUsed": 1,
            "toolCallMessages": [
                {
                    "role": "assistant",
                    "content": null,
                    "tool_calls": [{
                        "id": "c1",
                        "type": "function",
                        "function": {
                            "name": "get_task",
                            "arguments": "{\\"id\\":\\"t_5\\",\\"verbose\\":true}"
                        }
                    }]
                }
            ]
        }
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(ExecutionResponse.self, from: raw)
        let argString = response.toolCallMessages?.first?.toolCalls?.first?.function.arguments ?? ""
        let argData = argString.data(using: .utf8)!
        let args = try JSONDecoder().decode(JSONValue.self, from: argData)
        if case .object(let obj) = args {
            #expect(obj["id"] == .string("t_5"))
            #expect(obj["verbose"] == .bool(true))
        } else {
            Issue.record("Expected object, got \(args)")
        }
    }

    @Test func wireMessage_textContent_fromString() throws {
        let raw = #"{"role":"user","content":"hello"}"#.data(using: .utf8)!
        let msg = try JSONDecoder().decode(WireMessage.self, from: raw)
        #expect(msg.textContent == "hello")
    }

    @Test func wireMessage_textContent_fromNull_isNil() throws {
        let raw = #"{"role":"assistant","content":null}"#.data(using: .utf8)!
        let msg = try JSONDecoder().decode(WireMessage.self, from: raw)
        #expect(msg.textContent == nil)
    }

    @Test func executionStatus_codable_toolCallsRequired() throws {
        let data = #""tool_calls_required""#.data(using: .utf8)!
        let status = try JSONDecoder().decode(ExecutionStatus.self, from: data)
        #expect(status == .toolCallsRequired)
    }
}
