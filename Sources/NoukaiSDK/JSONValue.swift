import Foundation

/// A self-contained JSON value type. Used for tool arguments, tool results,
/// and all dynamic JSON fields in noukai's wire format.
///
/// `Codable` round-trips produce exactly the wire shape expected by the API.
public indirect enum JSONValue: Codable, Sendable, Equatable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    public init(from decoder: any Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null; return }
        if let v = try? c.decode(Bool.self)               { self = .bool(v); return }
        if let v = try? c.decode(Int.self)                { self = .int(v); return }
        if let v = try? c.decode(Double.self)             { self = .double(v); return }
        if let v = try? c.decode(String.self)             { self = .string(v); return }
        if let v = try? c.decode([JSONValue].self)        { self = .array(v); return }
        if let v = try? c.decode([String: JSONValue].self) { self = .object(v); return }
        throw DecodingError.dataCorruptedError(
            in: c, debugDescription: "Unrecognized JSON value"
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null:          try c.encodeNil()
        case .bool(let v):   try c.encode(v)
        case .int(let v):    try c.encode(v)
        case .double(let v): try c.encode(v)
        case .string(let v): try c.encode(v)
        case .array(let v):  try c.encode(v)
        case .object(let v): try c.encode(v)
        }
    }

    // MARK: - Ergonomic accessors

    /// The string value if this is `.string`, otherwise `nil`.
    public var stringValue: String? {
        if case .string(let v) = self { return v } else { return nil }
    }

    /// The int value if this is `.int`, otherwise `nil`.
    public var intValue: Int? {
        if case .int(let v) = self { return v } else { return nil }
    }

    /// The bool value if this is `.bool`, otherwise `nil`.
    public var boolValue: Bool? {
        if case .bool(let v) = self { return v } else { return nil }
    }

    /// The array value if this is `.array`, otherwise `nil`.
    public var arrayValue: [JSONValue]? {
        if case .array(let v) = self { return v } else { return nil }
    }

    /// The object value if this is `.object`, otherwise `nil`.
    public var objectValue: [String: JSONValue]? {
        if case .object(let v) = self { return v } else { return nil }
    }

    /// Whether this value is `.null`.
    public var isNull: Bool {
        if case .null = self { return true } else { return false }
    }
}

extension JSONValue {
    /// Re-encode an `Encodable` value into a `JSONValue`. Used when converting
    /// typed DTOs into the dynamic JSON value needed for tool arguments.
    public static func encode<T: Encodable>(_ value: T) -> JSONValue {
        do {
            let data = try JSONEncoder().encode(value)
            return try JSONDecoder().decode(JSONValue.self, from: data)
        } catch {
            preconditionFailure("Failed to re-encode \(T.self): \(error)")
        }
    }
}
