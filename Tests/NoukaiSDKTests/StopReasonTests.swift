import Testing
import Foundation
@testable import NoukaiSDK

@Suite("StopReason")
struct StopReasonTests {

    @Test func rawValues_areCorrect() {
        #expect(StopReason.endTurn.rawValue == "end_turn")
        #expect(StopReason.toolUse.rawValue == "tool_use")
        #expect(StopReason.maxTokens.rawValue == "max_tokens")
        #expect(StopReason.stopSequence.rawValue == "stop_sequence")
    }

    @Test func codable_roundTrip() throws {
        for reason: StopReason in [.endTurn, .toolUse, .maxTokens, .stopSequence] {
            let data = try JSONEncoder().encode(reason)
            let decoded = try JSONDecoder().decode(StopReason.self, from: data)
            #expect(decoded == reason)
        }
    }

    @Test func fromOpenAI_stop_isEndTurn() {
        #expect(StopReason.fromOpenAI("stop") == .endTurn)
    }

    @Test func fromOpenAI_toolCalls_isToolUse() {
        #expect(StopReason.fromOpenAI("tool_calls") == .toolUse)
    }

    @Test func fromOpenAI_length_isMaxTokens() {
        #expect(StopReason.fromOpenAI("length") == .maxTokens)
    }

    @Test func fromOpenAI_contentFilter_isStopSequence() {
        #expect(StopReason.fromOpenAI("content_filter") == .stopSequence)
    }

    @Test func fromOpenAI_unknown_isEndTurn() {
        #expect(StopReason.fromOpenAI(nil) == .endTurn)
        #expect(StopReason.fromOpenAI("other") == .endTurn)
    }
}
