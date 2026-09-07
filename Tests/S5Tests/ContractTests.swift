import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import S5
import S5Client
import Testing

enum Echo: Endpoint {
    struct Input: Codable, Sendable { let value: String }
    typealias Output = Input
    static let name = "echo.read"
}

enum Invalid: Endpoint {
    typealias Input = Empty
    typealias Output = Empty
    static let name = "../secrets"
}

@Test func stableAndValidatedPaths() throws {
    #expect(try Echo.path == "/api/v1/echo.read")
    #expect(throws: ContractError.self) { try Invalid.path }
    var catalog = EndpointCatalog()
    try catalog.register(Echo.self, as: "echo")
    #expect(throws: ContractError.self) { try catalog.register(Echo.self, as: "another") }
}

struct InspectingTransport: HTTPTransport {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        #expect(request.url?.absoluteString == "https://example.com/prefix/api/v1/echo.read")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        let input = try WireCodec.decode(Echo.Input.self, from: #require(request.httpBody))
        #expect(input.value == "hello")
        let url = try #require(request.url)
        let response = try #require(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
        return (try WireCodec.encode(input), response)
    }
}

@Test func typedClientPreservesPrefixAndHeaders() async throws {
    let client = try APIClient(baseURL: #require(URL(string: "https://example.com/prefix")),
                               transport: InspectingTransport(), headers: { ["Authorization": "Bearer test"] })
    let output = try await client.call(Echo.self, input: .init(value: "hello"))
    #expect(output.value == "hello")
}

struct FailingTransport: HTTPTransport {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let error = APIError(code: "future_error", message: "Please retry later.")
        let url = try #require(request.url)
        let response = try #require(HTTPURLResponse(url: url, statusCode: 429, httpVersion: nil, headerFields: nil))
        return (try WireCodec.encode(error), response)
    }
}

@Test func futureErrorCodesRemainDecodable() async throws {
    let client = try APIClient(baseURL: #require(URL(string: "https://example.com")), transport: FailingTransport())
    do {
        _ = try await client.call(Echo.self, input: .init(value: "hello"))
        Issue.record("Expected the remote error")
    } catch ClientError.remote(let status, let error) {
        #expect(status == 429)
        #expect(error.code == "future_error")
    }
}
