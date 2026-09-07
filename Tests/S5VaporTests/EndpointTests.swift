import Foundation
import S5
import S5Vapor
import Testing
import Vapor
import VaporTesting

enum Echo: Endpoint {
    struct Input: Codable, Sendable { let value: String }
    typealias Output = Input
    static let name = "echo"
    static func validate(_ input: Input) throws {
        if input.value.isEmpty { throw APIError.invalidInput("Value is required.") }
    }
}

@Test func endpointDecodesValidatesAndEncodes() async throws {
    try await withApp { app in
        app.middleware.use(EndpointErrorMiddleware())
        try app.endpoint(Echo.self) { input, _ in input }
        try await app.test(.POST, "/api/v1/echo", headers: ["Content-Type": "application/json"],
                           body: ByteBuffer(string: #"{"value":"hello"}"#)) { response in
            #expect(response.status == .ok)
            #expect(try response.content.decode(Echo.Output.self).value == "hello")
        }
        for body in [#"{"value":1}"#, #"{"value":""}"#, "not json"] {
            try await app.test(.POST, "/api/v1/echo", headers: ["Content-Type": "application/json"],
                               body: ByteBuffer(string: body)) { response in
                #expect(response.status == .badRequest)
                #expect(try response.content.decode(APIError.self).code == "invalid_input")
            }
        }
    }
}

@Test func serverErrorsDoNotExposeDetails() async throws {
    struct DatabaseFailure: Error {}
    try await withApp { app in
        try app.endpoint(Echo.self) { _, _ in throw DatabaseFailure() }
        try await app.test(.POST, "/api/v1/echo", headers: ["Content-Type": "application/json"],
                           body: ByteBuffer(string: #"{"value":"hello"}"#)) { response in
            #expect(response.status == .internalServerError)
            #expect(try response.content.decode(APIError.self).message == "An internal error occurred.")
        }
    }
}

@Test func rejectsNonJSONAndUnknownRoutes() async throws {
    try await withApp { app in
        app.middleware.use(EndpointErrorMiddleware())
        try app.endpoint(Echo.self) { input, _ in input }
        try await app.test(.POST, "/api/v1/echo", body: ByteBuffer(string: #"{"value":"hello"}"#)) { response in
            #expect(response.status == .unsupportedMediaType)
        }
        try await app.test(.POST, "/api/v1/missing") { response in
            #expect(response.status == .notFound)
            #expect(try response.content.decode(APIError.self).code == "http_404")
        }
    }
}

@Test func bodyLimitsAndAuthenticationCannotBeBypassed() async throws {
    struct Deny: AsyncMiddleware {
        func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
            throw Abort(.unauthorized)
        }
    }
    try await withApp { app in
        app.middleware.use(EndpointErrorMiddleware())
        try app.endpoint(Echo.self, bodyLimit: 20) { input, _ in input }
        let response = try await app.sendRequest(.POST, "/api/v1/echo", headers: ["Content-Type": "application/json"],
            body: ByteBuffer(string: #"{"value":"this payload exceeds twenty bytes"}"#))
        #expect(response.status == .payloadTooLarge)
        #expect(try response.content.decode(APIError.self).code == "http_413")
    }
    try await withApp { app in
        app.middleware.use(EndpointErrorMiddleware())
        try app.grouped(Deny()).endpoint(Echo.self) { input, _ in
            Issue.record("An unauthorized request reached the handler")
            return input
        }
        let response = try await app.sendRequest(.POST, "/api/v1/echo", headers: ["Content-Type": "application/json"],
            body: ByteBuffer(string: #"{"value":"hello"}"#))
        #expect(response.status == .unauthorized)
        #expect(try response.content.decode(APIError.self).code == "http_401")
    }
}
