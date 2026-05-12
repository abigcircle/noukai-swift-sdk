import Foundation

/// Why a model stopped generating. Mirrors the values noukai surfaces from
/// its underlying model provider. Used by consumers of `ExecutionResponse`
/// to distinguish answers from tool calls and to detect truncation.
public enum StopReason: String, Codable, Sendable, Equatable {
    case endTurn = "end_turn"
    case toolUse = "tool_use"
    case maxTokens = "max_tokens"
    case stopSequence = "stop_sequence"

    /// Maps OpenAI / OpenRouter `finish_reason` strings to `StopReason`.
    public static func fromOpenAI(_ reason: String?) -> StopReason {
        switch reason {
        case "stop":           return .endTurn
        case "tool_calls":     return .toolUse
        case "length":         return .maxTokens
        case "content_filter": return .stopSequence
        default:               return .endTurn
        }
    }
}
