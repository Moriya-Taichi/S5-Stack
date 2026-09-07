import Foundation
import S5
import Vapor

public extension RoutesBuilder {
    /// Mounts a versioned JSON endpoint. Group middleware still runs, so use a protected group
    /// for authenticated endpoints. All endpoints use POST, including read operations.
    @discardableResult
    func endpoint<E: Endpoint>(
        _ endpoint: E.Type,
        bodyLimit: ByteCount = "64kb",
        use handler: @escaping @Sendable (E.Input, Request) async throws -> E.Output
    ) throws -> Route {
        let path = try E.path.split(separator: "/").map { PathComponent.constant(String($0)) }
        return on(.POST, path, body: .collect(maxSize: bodyLimit)) { request async throws -> Response in
            do {
                guard let contentType = request.headers.contentType,
                      contentType.type.lowercased() == "application",
                      contentType.subType.lowercased() == "json" else {
                    throw Abort(.unsupportedMediaType)
                }
                guard let buffer = request.body.data else {
                    throw APIError.invalidInput("A JSON request body is required.")
                }
                guard buffer.readableBytes <= bodyLimit.value else { throw Abort(.payloadTooLarge) }
                let input: E.Input
                do {
                    input = try WireCodec.decode(E.Input.self, from: Data(buffer.readableBytesView))
                } catch {
                    throw APIError.invalidInput("The request does not match the endpoint input.")
                }
                try E.validate(input)
                let output = try await handler(input, request)
                return Response(status: .ok, headers: ["Content-Type": "application/json", "Cache-Control": "no-store"],
                                body: .init(data: try WireCodec.encode(output)))
            } catch {
                return try endpointErrorResponse(error, request: request)
            }
        }
    }
}

/// Also normalizes router, authentication, and body-limit failures that happen before a handler.
/// Install after Vapor's default ErrorMiddleware and before authentication/file middleware.
public struct EndpointErrorMiddleware: AsyncMiddleware {
    public init() {}

    public func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        guard request.url.path.hasPrefix("/api/") else {
            return try await next.respond(to: request)
        }
        do { return try await next.respond(to: request) }
        catch { return try endpointErrorResponse(error, request: request) }
    }
}

private func endpointErrorResponse(_ error: any Error, request: Request) throws -> Response {
    let status: HTTPResponseStatus
    let payload: APIError
    var headers = HTTPHeaders()
    if let error = error as? APIError {
        switch error.code {
        case "invalid_input": status = .badRequest
        case "unauthenticated": status = .unauthorized
        case "forbidden": status = .forbidden
        case "not_found": status = .notFound
        case "conflict": status = .conflict
        default: status = .internalServerError
        }
        payload = status.code < 500 ? error : APIError(code: "internal_error", message: "An internal error occurred.")
    } else if let error = error as? any AbortError {
        status = error.status
        headers = error.headers
        payload = APIError(code: "http_\(status.code)", message: status.reasonPhrase)
    } else {
        request.logger.report(error: error)
        status = .internalServerError
        payload = APIError(code: "internal_error", message: "An internal error occurred.")
    }
    headers.replaceOrAdd(name: .contentType, value: "application/json")
    headers.replaceOrAdd(name: .cacheControl, value: "no-store")
    return Response(status: status, headers: headers, body: .init(data: try WireCodec.encode(payload)))
}
