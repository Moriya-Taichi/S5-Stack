import Foundation

/// A wire contract shared by the server and Swift clients. Implementations and database models
/// belong in the server target, never in the contract target.
public protocol Endpoint: Sendable {
    associatedtype Input: Codable & Sendable
    associatedtype Output: Codable & Sendable

    /// Stable wire name, independent of the Swift type name (for example, `notes.create`).
    static var name: String { get }
    /// Increment when making an incompatible wire change; keep old routes while clients use them.
    static var version: Int { get }
    /// Validates untrusted input after decoding. The server always calls this before the handler.
    static func validate(_ input: Input) throws
}

public extension Endpoint {
    static var version: Int { 1 }
    static func validate(_ input: Input) throws {}

    static var path: String {
        get throws {
            guard version > 0, !name.isEmpty, name.utf8.count <= 120,
                  name.split(separator: ".", omittingEmptySubsequences: false).allSatisfy({ part in
                      !part.isEmpty && part.utf8.allSatisfy {
                          (97...122).contains($0) || (48...57).contains($0) || $0 == 45
                      }
                  }) else {
                throw ContractError.invalidEndpointName(name)
            }
            return "/api/v\(version)/\(name)"
        }
    }
}

public enum ContractError: Error, Equatable, Sendable {
    case invalidEndpointName(String)
    case duplicateEndpoint(String)
}

/// JSON `{}` for endpoints that take no input or return no payload.
public struct Empty: Codable, Sendable, Equatable {
    public init() {}
}

/// An intentionally small and stable error envelope. Unknown future codes remain decodable.
public struct APIError: Error, Codable, Sendable, Equatable {
    public let code: String
    public let message: String

    public init(code: String, message: String) {
        self.code = code
        self.message = message
    }

    public static func invalidInput(_ message: String) -> Self {
        .init(code: "invalid_input", message: message)
    }

    public static func notFound(_ message: String = "Resource not found.") -> Self {
        .init(code: "not_found", message: message)
    }
}

/// The same codec is used by the server and the URLSession client. Dates travel as ISO 8601 strings.
public enum WireCodec {
    public static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }

    public static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: data)
    }
}
