import Foundation

// MARK: - Execution status

/// The terminal or intermediate status of a noukai flow execution.
public enum ExecutionStatus: String, Codable, Sendable, Equatable {
    /// The flow completed successfully.
    case completed

    /// The flow terminated with an error.
    case failed

    /// The flow paused and is waiting for tool call results.
    case toolCallsRequired = "tool_calls_required"
}

// MARK: - Top-level response envelope

/// The raw response envelope returned by noukai's `/execute` endpoint.
/// `NoukaiClient` returns this directly; higher-level parsing (e.g. into
/// domain `CompletionResponse` shapes) is left to the consumer.
public struct ExecutionResponse: Codable, Sendable {
    /// Terminal or intermediate execution status.
    public let status: ExecutionStatus

    /// Present when `status == .completed` or `status == .failed`.
    public let result: JSONValue?

    /// Opaque execution identifier. Required to resume a paused execution.
    public let executionId: String?

    /// The step name at which the execution paused.
    public let pausedAtStep: String?

    /// Number of agent iterations consumed so far.
    public let iterationsUsed: Int?

    /// The conversation messages including the assistant's tool-call request.
    /// Present when `status == .toolCallsRequired`.
    public let toolCallMessages: [WireMessage]?

    /// Accumulated outputs from prior steps, forwarded verbatim on resume.
    public let accumulatedOutputs: JSONValue?

    /// The flow identifier. Informational.
    public let flowId: String?

    /// Number of blocks in the flow. Informational.
    public let blockCount: Int?
}

// MARK: - Wire message types

/// A message inside noukai's `toolCallMessages` array.
public struct WireMessage: Codable, Sendable {
    /// The role of the message author, e.g. `"assistant"` or `"tool"`.
    public let role: String

    /// The text or structured content of the message, if any.
    public let content: JSONValue?

    /// Tool calls requested by the assistant. Present on `role == "assistant"` messages.
    public let toolCalls: [WireToolCall]?

    /// The tool call ID this message responds to. Present on `role == "tool"` messages.
    public let toolCallId: String?

    private enum CodingKeys: String, CodingKey {
        case role, content
        case toolCalls = "tool_calls"
        case toolCallId = "tool_call_id"
    }

    /// Extracts the text content when `content` is a plain string.
    public var textContent: String? {
        guard let content else { return nil }
        if case .string(let s) = content { return s }
        return nil
    }
}

/// A single tool call requested by the assistant.
public struct WireToolCall: Codable, Sendable {
    /// The unique identifier of this tool call, referenced in tool result messages.
    public let id: String

    /// The call type. Currently always `"function"`.
    public let type: String?

    /// The function being called.
    public let function: WireFunction
}

/// The function name and serialised arguments within a `WireToolCall`.
public struct WireFunction: Codable, Sendable {
    /// The name of the tool / function to call.
    public let name: String

    /// The arguments to pass, serialised as a JSON string.
    public let arguments: String
}
