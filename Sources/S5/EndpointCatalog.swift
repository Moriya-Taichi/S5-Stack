import Foundation

/// Exports wire locations for the browser without exposing server code or Swift implementation names.
/// This is a route manifest, not a JSON Schema or a proof of compatibility with older applications.
public struct EndpointCatalog: Sendable {
    public private(set) var routes: [String: String] = [:]

    public init() {}

    public mutating func register<E: Endpoint>(_ endpoint: E.Type, as key: String) throws {
        let path = try E.path
        guard routes[key] == nil, !routes.values.contains(path) else {
            throw ContractError.duplicateEndpoint(path)
        }
        routes[key] = path
    }

    public func json() throws -> Data { try WireCodec.encode(routes) }
}
