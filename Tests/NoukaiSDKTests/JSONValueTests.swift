import Testing
import Foundation
@testable import NoukaiSDK

@Suite("JSONValue")
struct JSONValueTests {

    @Test func roundTrip_null() throws {
        let encoded = try JSONEncoder().encode(JSONValue.null)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: encoded)
        #expect(decoded == .null)
        #expect(decoded.isNull)
    }

    @Test func roundTrip_bool() throws {
        let encoded = try JSONEncoder().encode(JSONValue.bool(true))
        let decoded = try JSONDecoder().decode(JSONValue.self, from: encoded)
        #expect(decoded == .bool(true))
        #expect(decoded.boolValue == true)
    }

    @Test func roundTrip_int() throws {
        let encoded = try JSONEncoder().encode(JSONValue.int(42))
        let decoded = try JSONDecoder().decode(JSONValue.self, from: encoded)
        #expect(decoded == .int(42))
        #expect(decoded.intValue == 42)
    }

    @Test func roundTrip_double() throws {
        let encoded = try JSONEncoder().encode(JSONValue.double(3.14))
        let decoded = try JSONDecoder().decode(JSONValue.self, from: encoded)
        #expect(decoded == .double(3.14))
    }

    @Test func roundTrip_string() throws {
        let encoded = try JSONEncoder().encode(JSONValue.string("hello"))
        let decoded = try JSONDecoder().decode(JSONValue.self, from: encoded)
        #expect(decoded == .string("hello"))
        #expect(decoded.stringValue == "hello")
    }

    @Test func roundTrip_array() throws {
        let value = JSONValue.array([.int(1), .string("two"), .bool(false)])
        let encoded = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: encoded)
        #expect(decoded == value)
        #expect(decoded.arrayValue?.count == 3)
    }

    @Test func roundTrip_object() throws {
        let value = JSONValue.object(["key": .string("value"), "num": .int(7)])
        let encoded = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: encoded)
        #expect(decoded == value)
        #expect(decoded.objectValue?["key"] == .string("value"))
    }

    @Test func decode_fromLiteralJSON_string() throws {
        let data = #""hello world""#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
        #expect(decoded == .string("hello world"))
    }

    @Test func decode_fromLiteralJSON_number() throws {
        let data = "123".data(using: .utf8)!
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
        #expect(decoded == .int(123))
    }

    @Test func decode_fromLiteralJSON_null() throws {
        let data = "null".data(using: .utf8)!
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
        #expect(decoded.isNull)
    }

    @Test func encode_staticHelper_encodable() {
        struct Point: Encodable { let x: Int; let y: Int }
        let value = JSONValue.encode(Point(x: 1, y: 2))
        if case .object(let obj) = value {
            #expect(obj["x"] == .int(1))
            #expect(obj["y"] == .int(2))
        } else {
            Issue.record("Expected object, got \(value)")
        }
    }

    @Test func accessors_returnNilForWrongCase() {
        let str = JSONValue.string("hello")
        #expect(str.intValue == nil)
        #expect(str.boolValue == nil)
        #expect(str.arrayValue == nil)
        #expect(str.objectValue == nil)
        #expect(str.isNull == false)
    }
}
