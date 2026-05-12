import Foundation

/// A tool definition that the SDK forwards to noukai so the model can request
/// tool calls. The `parameters` field must be a JSON Schema object describing
/// the tool's input shape.
public struct ToolSpec: Sendable, Encodable {
    /// The tool / function name.
    public let name: String

    /// A human-readable description of what the tool does.
    public let description: String

    /// A JSON Schema object describing the tool's input parameters.
    public let parameters: JSONValue

    /// Creates a tool specification.
    ///
    /// - Parameters:
    ///   - name: Tool name used when the model requests a call.
    ///   - description: Description surfaced to the model.
    ///   - parameters: JSON Schema object for the tool's inputs.
    public init(name: String, description: String, parameters: JSONValue) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }
}
