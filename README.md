# NoukaiSDK

Swift client for the [noukai](https://noukai.xyz) slug-execution API.

Noukai runs agent loops server-side. This SDK handles the execute / pause / resume protocol so your app can focus on tool dispatch rather than HTTP plumbing.

**Zero dependencies** — Foundation only. Works on macOS 14+, iOS 17+.

---

## Installation

### Swift Package Manager

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/abigcircle/noukai-swift-sdk.git", from: "1.0.0"),
]

// In your target:
.target(
    name: "MyApp",
    dependencies: [
        .product(name: "NoukaiSDK", package: "noukai-swift-sdk"),
    ]
)
```

---

## Quick start

```swift
import NoukaiSDK

// 1. Configure
let config = NoukaiConfiguration(org: "my-org", project: "my-project", flow: "agent-loop")
let client = NoukaiClient(configuration: config)

// 2. Execute
let request = ExecutionRequest(message: "List all open tasks", apiKey: "nk_live_...")
let response = try await client.execute(request)

// 3. Handle response
switch response.status {
case .completed:
    print("Done:", response.result ?? .null)
case .toolCallsRequired:
    // dispatch tools, then resume (see below)
case .failed:
    print("Failed:", response.result ?? .null)
}
```

---

## Core concepts

### Configuration

`NoukaiConfiguration` builds the execution URL from org / project / flow slugs. Optionally pin a flow version:

```swift
// Latest version (default)
let config = NoukaiConfiguration(org: "acme", project: "support-bot", flow: "triage")

// Pinned to version 3
let config = NoukaiConfiguration(org: "acme", project: "support-bot", flow: "triage", version: 3)
// URL: https://api.noukai.xyz/api/v1/seq/acme/support-bot/triage/execute?version=3

// Custom base URL (self-hosted)
let config = NoukaiConfiguration(
    baseURL: URL(string: "https://noukai.internal.company.com")!,
    org: "acme"
)
```

### Execute / resume cycle

Noukai's agent loop can pause mid-execution when it needs tool results. The SDK manages this state automatically:

```swift
let client = NoukaiClient(configuration: config)

// Step 1: Send initial message
let request = ExecutionRequest(
    message: "Close task #5 and update #3 to done",
    apiKey: apiKey,
    tools: myTools,
    toolChoice: "auto"
)
let response = try await client.execute(request)

// Step 2: If paused for tool calls, dispatch tools and resume
if response.status == .toolCallsRequired,
   let messages = response.toolCallMessages,
   let lastAssistant = messages.last(where: { $0.role == "assistant" }) {

    var results: [ToolResult] = []
    for call in lastAssistant.toolCalls ?? [] {
        let output = dispatchTool(name: call.function.name, args: call.function.arguments)
        results.append(ToolResult(toolCallId: call.id, content: output))
    }

    // Resume — client automatically sends stored executionId + pausedAtStep
    let resumed = try await client.resume(with: results, apiKey: apiKey)
    // resumed.status may be .completed, .failed, or .toolCallsRequired again
}
```

The client stores resume state internally. You can call `resume(with:apiKey:)` multiple times if the flow pauses repeatedly. Call `resetExecution()` to abandon a paused flow:

```swift
await client.resetExecution()
```

### Providing tools

Define tools with `ToolSpec`. The `parameters` field is a JSON Schema as `JSONValue`:

```swift
let tools: [ToolSpec] = [
    ToolSpec(
        name: "search_tasks",
        description: "Search tasks by keyword",
        parameters: .object([
            "type": .string("object"),
            "properties": .object([
                "query": .object([
                    "type": .string("string"),
                    "description": .string("Search keyword"),
                ]),
            ]),
            "required": .array([.string("query")]),
        ])
    ),
    ToolSpec(
        name: "close_task",
        description: "Close a task by ID",
        parameters: .object([
            "type": .string("object"),
            "properties": .object([
                "task_id": .object([
                    "type": .string("string"),
                ]),
            ]),
            "required": .array([.string("task_id")]),
        ])
    ),
]

let request = ExecutionRequest(
    message: "Close all billing tasks",
    apiKey: apiKey,
    tools: tools,
    toolChoice: "auto"
)
```

### Passing context parameters

Send arbitrary context to the flow via `parameters`:

```swift
let request = ExecutionRequest(
    message: "What tasks are overdue?",
    apiKey: apiKey,
    parameters: [
        "context": .object([
            "projects": .array([
                .object(["id": .string("p_1"), "name": .string("Backend")]),
                .object(["id": .string("p_2"), "name": .string("Frontend")]),
            ]),
            "task_count": .int(42),
            "active_filter": .null,
        ]),
    ]
)
```

### Key validation

Validate an API key before storing it:

```swift
let result = await client.validateKey("nk_live_Ab12_secretkey123456", allowTest: false)
switch result {
case .success:
    print("Key accepted")
case .failure(let error):
    print("Invalid:", error)
}
```

Format-check without a network call:

```swift
let formatCheck = ApiKeyFormat.validate("nk_live_Ab12_secret", allowTest: false)
// .success(()) or .failure(.invalidKeyFormat(...))
```

Mask a key for display:

```swift
ApiKeyFormat.mask("nk_live_Ab12CdEf_your32charsecrethere1234567890ab")
// "nk_live_Ab12CdEf_…7890ab"
```

---

## API reference

### `NoukaiClient` (actor)

| Method | Description |
|---|---|
| `execute(_ request: ExecutionRequest) async throws -> ExecutionResponse` | Start a new flow execution. Clears any prior resume state. |
| `resume(with toolResults: [ToolResult], apiKey: String) async throws -> ExecutionResponse` | Resume a paused execution with tool outputs. Throws `NoukaiError.noResumeState` if no execution is paused. |
| `resetExecution()` | Abandon a paused execution and clear stored state. |
| `validateKey(_ key: String, allowTest: Bool) async -> Result<Void, NoukaiError>` | Probe the server to verify an API key is accepted. Format-checks first without a network call. |

### `ExecutionRequest`

| Property | Type | Description |
|---|---|---|
| `message` | `String` | The user's natural-language input. |
| `apiKey` | `String` | Bearer token for authentication. |
| `tools` | `[ToolSpec]?` | Tool definitions available to the flow. `nil` disables tool use. |
| `toolChoice` | `String?` | Hint: `"auto"`, `"none"`, or a specific tool name. |
| `parameters` | `[String: JSONValue]?` | Arbitrary key-value context forwarded to the flow. |

### `ExecutionResponse`

| Property | Type | Description |
|---|---|---|
| `status` | `ExecutionStatus` | `.completed`, `.failed`, or `.toolCallsRequired`. |
| `result` | `JSONValue?` | The flow's output (when completed or failed). May be a string, object, or null. |
| `executionId` | `String?` | Opaque ID for resume. Present when paused. |
| `pausedAtStep` | `String?` | The step name where execution paused. |
| `iterationsUsed` | `Int?` | Agent iterations consumed so far. |
| `toolCallMessages` | `[WireMessage]?` | Conversation messages including tool-call requests. Present when paused. |
| `accumulatedOutputs` | `JSONValue?` | Outputs from prior steps, forwarded on resume. |
| `flowId` | `String?` | Flow identifier (informational). |
| `blockCount` | `Int?` | Number of blocks in the flow (informational). |

### `ExecutionStatus`

```swift
case completed            // Flow finished successfully
case failed               // Flow terminated with error
case toolCallsRequired    // Flow paused — dispatch tools and call resume()
```

### Wire types (in `toolCallMessages`)

```
WireMessage
├── role: String              ("assistant" or "tool")
├── content: JSONValue?       (text content, if any)
├── toolCalls: [WireToolCall]? (present on assistant messages)
│   └── WireToolCall
│       ├── id: String        (referenced in ToolResult.toolCallId)
│       ├── type: String?     ("function")
│       └── function: WireFunction
│           ├── name: String
│           └── arguments: String  (JSON-encoded arguments)
└── toolCallId: String?       (present on tool result messages)
```

Use `WireMessage.textContent` to extract a plain-string `content`:

```swift
if let text = message.textContent {
    print("Assistant said:", text)
}
```

### `NoukaiError`

| Case | When |
|---|---|
| `.noApiKey` | No key provided. |
| `.invalidKeyFormat(String)` | Key doesn't match `nk_live_` / `nk_test_` prefix. |
| `.keyRejected(String)` | Server returned 401 or 403. |
| `.httpError(statusCode: Int, body: String)` | Non-2xx HTTP response. |
| `.decodingError(String)` | Response body couldn't be decoded. |
| `.networkError(String)` | Transport failure (no connectivity, timeout, etc.). |
| `.noResumeState` | `resume(with:)` called without a paused execution. |

### `JSONValue`

A type-safe representation of any JSON value. Used for tool parameters, response results, and arbitrary data:

```swift
case null
case bool(Bool)
case int(Int)
case double(Double)
case string(String)
case array([JSONValue])
case object([String: JSONValue])
```

Convenience accessors: `.stringValue`, `.intValue`, `.boolValue`, `.arrayValue`, `.objectValue`, `.isNull`.

Encode any `Encodable` to `JSONValue`:

```swift
let value = JSONValue.encode(myStruct)
```

---

## Testing

Inject a custom `URLSession` to mock HTTP responses:

```swift
let client = NoukaiClient(configuration: config, session: mockSession)
```

---

## Key format

| Environment | Prefix | Example |
|---|---|---|
| Production | `nk_live_` | `nk_live_Ab12CdEf_your32charsecret...` |
| Development | `nk_test_` | `nk_test_Ab12CdEf_your32charsecret...` |

Test keys are rejected unless `allowTest: true` is passed to `validateKey()` or `ApiKeyFormat.validate()`.

---

## License

See [LICENSE](LICENSE).
