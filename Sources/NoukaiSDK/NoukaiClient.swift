import Foundation

// MARK: - Internal types

/// State stored between `execute(_:)` and `resume(with:)` when noukai pauses
/// for tool call results.
private struct ResumeState: Sendable {
    let executionId: String
    let pausedAtStep: String
    let iterationsUsed: Int
    let toolCallMessages: [WireMessage]
    let accumulatedOutputs: JSONValue?
}

// MARK: - Wire request bodies (internal)

private struct InitialRequestBody: Encodable {
    let message: String
    let tools: [WireToolDef]?
    let toolChoice: String?
    let parameters: [String: JSONValue]?
}

private struct ResumeRequestBody: Encodable {
    let executionId: String
    let pausedAtStep: String
    let iterationsUsed: Int
    let toolCallMessages: JSONValue
    let accumulatedOutputs: JSONValue?
    let tools: [WireToolDef]?
}

private struct WireToolDef: Encodable {
    let type: String = "function"
    let function: WireToolFunction
}

private struct WireToolFunction: Encodable {
    let name: String
    let description: String
    let parameters: JSONValue
}

// MARK: - Client

/// HTTP client for noukai's slug-execution API.
///
/// Noukai manages the agent loop server-side: the caller sends an
/// `ExecutionRequest`, noukai pauses when tool calls are needed
/// (`status: "tool_calls_required"`), and the caller resumes with
/// `ToolResult` values.
///
/// The client stores pause/resume state internally between calls, so the
/// consumer can treat each step as a simple request/response cycle.
///
/// Inject a custom `URLSession` (via `MockURLProtocol`) to test without
/// hitting the network.
public actor NoukaiClient {

    // MARK: - Properties

    /// The configuration used to build API URLs.
    public let configuration: NoukaiConfiguration

    private let session: URLSession
    private var resumeState: ResumeState?

    static let userAgent = "NoukaiSDK/1.0"

    // MARK: - Init

    /// Creates a client with the given configuration.
    ///
    /// - Parameters:
    ///   - configuration: API endpoint configuration.
    ///   - session: The `URLSession` to use for requests. Defaults to `.shared`.
    public init(configuration: NoukaiConfiguration, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
    }

    // MARK: - Public API

    /// Execute a flow with the given request.
    ///
    /// Sends a `POST` to `configuration.executeURL` with `{ message, tools, toolChoice, parameters }`.
    /// If a previous call returned `toolCallsRequired` and `resetExecution()` has not been called,
    /// calling `execute(_:)` after a resume cycle will start a fresh execution (resetting state first).
    ///
    /// - Parameter request: The execution inputs, including the API key.
    /// - Returns: The raw `ExecutionResponse` from noukai.
    /// - Throws: `NoukaiError` on network, HTTP, or decoding failure.
    public func execute(_ request: ExecutionRequest) async throws -> ExecutionResponse {
        // Fresh execution — clear any stale resume state.
        resumeState = nil

        let body = InitialRequestBody(
            message: request.message,
            tools: wireTools(from: request.tools),
            toolChoice: request.toolChoice,
            parameters: request.parameters
        )

        return try await send(body: body, apiKey: request.apiKey)
    }

    /// Resume a paused execution with tool call results.
    ///
    /// Must be called only after a previous `execute(_:)` or `resume(with:)` returned
    /// an `ExecutionResponse` with `status == .toolCallsRequired`. The client stores
    /// the pause state automatically; call this with the tool outputs to continue.
    ///
    /// - Parameter toolResults: Results for each `WireToolCall` in the paused response.
    /// - Returns: The raw `ExecutionResponse` from noukai.
    /// - Throws: `NoukaiError.noResumeState` if called without a paused execution,
    ///   or other `NoukaiError` on transport/decoding failure.
    public func resume(with toolResults: [ToolResult], apiKey: String) async throws -> ExecutionResponse {
        guard let state = resumeState else {
            throw NoukaiError.noResumeState
        }

        let updatedMessages = appendedToolResults(toolResults, to: state.toolCallMessages)

        let body = ResumeRequestBody(
            executionId: state.executionId,
            pausedAtStep: state.pausedAtStep,
            iterationsUsed: state.iterationsUsed,
            toolCallMessages: updatedMessages,
            accumulatedOutputs: state.accumulatedOutputs,
            tools: nil
        )

        resumeState = nil
        return try await send(body: body, apiKey: apiKey)
    }

    /// Clear any stored resume state, abandoning a paused execution.
    ///
    /// Call this on cancellation or error recovery so that the next `execute(_:)`
    /// starts a fresh flow run.
    public func resetExecution() {
        resumeState = nil
    }

    /// Validate that an API key is accepted by noukai.
    ///
    /// Sends a minimal probe request and returns `.success(())` on HTTP 2xx.
    /// Returns `.failure(.invalidKeyFormat(...))` without making a network call
    /// when the key format is wrong.
    ///
    /// - Parameters:
    ///   - key: The raw API key to validate.
    ///   - allowTest: Pass `true` in debug builds to accept `nk_test_` keys.
    /// - Returns: `.success(())` or a `NoukaiError` failure.
    public func validateKey(_ key: String, allowTest: Bool = false) async -> Result<Void, NoukaiError> {
        let formatResult = ApiKeyFormat.validate(key, allowTest: allowTest)
        if case .failure(let err) = formatResult {
            return .failure(err)
        }

        var request = URLRequest(url: configuration.executeURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")

        let probeBody: [String: String] = ["message": "ping"]
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: probeBody)
        } catch {
            return .failure(.networkError("Failed to encode probe request"))
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            return .failure(.networkError(error.localizedDescription))
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            return .failure(.networkError("Non-HTTP response"))
        }

        let responseBody = String(data: data, encoding: .utf8) ?? ""

        switch httpResponse.statusCode {
        case 200...299:
            return .success(())
        case 401, 403:
            return .failure(.keyRejected("Key rejected by noukai: \(responseBody)"))
        default:
            return .failure(.networkError("HTTP \(httpResponse.statusCode)"))
        }
    }

    // MARK: - Private helpers

    private func send<Body: Encodable>(body: Body, apiKey: String) async throws -> ExecutionResponse {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let bodyData: Data
        do {
            bodyData = try encoder.encode(body)
        } catch {
            throw NoukaiError.networkError("Failed to encode request body: \(error.localizedDescription)")
        }

        var request = URLRequest(url: configuration.executeURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.httpBody = bodyData

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw NoukaiError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NoukaiError.networkError("Non-HTTP response")
        }

        let responseBody = String(data: data, encoding: .utf8) ?? ""

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NoukaiError.httpError(statusCode: httpResponse.statusCode, body: responseBody)
        }

        do {
            let decoded = try JSONDecoder().decode(ExecutionResponse.self, from: data)

            // Store resume state if the flow paused for tool calls.
            if decoded.status == .toolCallsRequired,
               let execId = decoded.executionId,
               let step = decoded.pausedAtStep,
               let iters = decoded.iterationsUsed,
               let msgs = decoded.toolCallMessages {
                resumeState = ResumeState(
                    executionId: execId,
                    pausedAtStep: step,
                    iterationsUsed: iters,
                    toolCallMessages: msgs,
                    accumulatedOutputs: decoded.accumulatedOutputs
                )
            }

            return decoded
        } catch {
            throw NoukaiError.decodingError(error.localizedDescription)
        }
    }

    /// Convert `ToolSpec` values into the wire format noukai expects.
    private func wireTools(from specs: [ToolSpec]?) -> [WireToolDef]? {
        guard let specs, !specs.isEmpty else { return nil }
        return specs.map { spec in
            WireToolDef(function: WireToolFunction(
                name: spec.name,
                description: spec.description,
                parameters: spec.parameters
            ))
        }
    }

    /// Re-encode the stored `WireMessage` array and append new tool result messages.
    private func appendedToolResults(
        _ results: [ToolResult],
        to messages: [WireMessage]
    ) -> JSONValue {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        var arrayValues: [JSONValue] = []

        if let data = try? encoder.encode(messages),
           let decoded = try? JSONDecoder().decode(JSONValue.self, from: data),
           case .array(let arr) = decoded {
            arrayValues = arr
        }

        for result in results {
            arrayValues.append(.object([
                "role": .string("tool"),
                "tool_call_id": .string(result.toolCallId),
                "content": .string(result.content),
            ]))
        }

        return .array(arrayValues)
    }
}
