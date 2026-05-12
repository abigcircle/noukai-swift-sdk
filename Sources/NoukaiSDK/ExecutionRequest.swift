import Foundation

/// All inputs needed to start a new noukai flow execution.
public struct ExecutionRequest: Sendable {
    /// The natural-language message from the user.
    public let message: String

    /// The Bearer API key used to authenticate with noukai.
    public let apiKey: String

    /// Tool definitions made available to the flow. Pass `nil` or empty to disable tool use.
    public let tools: [ToolSpec]?

    /// Tool-choice hint sent to the model, e.g. `"auto"` or `"none"`.
    public let toolChoice: String?

    /// Arbitrary key-value parameters forwarded to the flow (e.g. context snapshot).
    public let parameters: [String: JSONValue]?

    /// Creates an execution request.
    ///
    /// - Parameters:
    ///   - message: The user's natural-language message.
    ///   - apiKey: Bearer API key for authentication.
    ///   - tools: Optional tool definitions. Pass `nil` to disable tool use.
    ///   - toolChoice: Optional tool-choice hint (`"auto"`, `"none"`, etc.).
    ///   - parameters: Optional flow parameters.
    public init(
        message: String,
        apiKey: String,
        tools: [ToolSpec]? = nil,
        toolChoice: String? = nil,
        parameters: [String: JSONValue]? = nil
    ) {
        self.message = message
        self.apiKey = apiKey
        self.tools = tools
        self.toolChoice = toolChoice
        self.parameters = parameters
    }
}

/// A tool result returned by the consumer after a `toolCallsRequired` response.
public struct ToolResult: Sendable {
    /// The tool call ID this result responds to (matches `WireToolCall.id`).
    public let toolCallId: String

    /// The string output of the tool execution.
    public let content: String

    /// Creates a tool result.
    ///
    /// - Parameters:
    ///   - toolCallId: ID of the tool call being answered.
    ///   - content: String representation of the tool output.
    public init(toolCallId: String, content: String) {
        self.toolCallId = toolCallId
        self.content = content
    }
}
