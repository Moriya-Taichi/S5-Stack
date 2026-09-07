import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import S5

public enum ClientError: Error, Sendable {
    case invalidBaseURL
    case invalidResponse
    case httpStatus(Int)
    case remote(status: Int, error: APIError)
}

/// A transport seam for tests and applications with their own authentication or networking layer.
public protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public struct URLSessionTransport: HTTPTransport {
    public let session: URLSession

    public init(session: URLSession = .shared) { self.session = session }

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw ClientError.invalidResponse }
        return (data, response)
    }
}

/// Calls an endpoint using its shared input and output types, without generated Swift stubs.
public struct APIClient: Sendable {
    private let baseURL: URL
    private let transport: any HTTPTransport
    private let headers: @Sendable () async throws -> [String: String]

    /// `baseURL` may include a reverse proxy prefix. Headers are obtained for every request so
    /// applications can supply refreshed bearer credentials without rebuilding the client.
    public init(
        baseURL: URL,
        transport: any HTTPTransport = URLSessionTransport(),
        headers: @escaping @Sendable () async throws -> [String: String] = { [:] }
    ) throws {
        guard ["https", "http"].contains(baseURL.scheme?.lowercased()),
              baseURL.host != nil, baseURL.user == nil, baseURL.password == nil,
              baseURL.query == nil, baseURL.fragment == nil else {
            throw ClientError.invalidBaseURL
        }
        self.baseURL = baseURL
        self.transport = transport
        self.headers = headers
    }

    public func call<E: Endpoint>(_ endpoint: E.Type, input: E.Input) async throws -> E.Output {
        try E.validate(input)
        let path = try E.path
        let url = baseURL.appendingPathComponent(String(path.dropFirst()))
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        for (key, value) in try await headers() { request.setValue(value, forHTTPHeaderField: key) }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try WireCodec.encode(input)
        let (data, response) = try await transport.send(request)
        guard (200..<300).contains(response.statusCode) else {
            if let error = try? WireCodec.decode(APIError.self, from: data) {
                throw ClientError.remote(status: response.statusCode, error: error)
            }
            throw ClientError.httpStatus(response.statusCode)
        }
        return try WireCodec.decode(E.Output.self, from: data)
    }

    public func call<E: Endpoint>(_ endpoint: E.Type) async throws -> E.Output where E.Input == Empty {
        try await call(endpoint, input: Empty())
    }
}
