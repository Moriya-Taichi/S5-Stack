import Foundation
import Ignite
import S5

public extension Site {
    /// Publishes Ignite HTML and a browser client whose URLs come from the shared Swift contracts.
    /// Browser event handlers remain JavaScript; input validation always happens on the server.
    mutating func publish(
        api: EndpointCatalog,
        sourceDirectory: URL,
        buildDirectory: URL
    ) async throws {
        try await publish(sourceDirectory: sourceDirectory, buildDirectory: buildDirectory)
        guard FileManager.default.fileExists(atPath: buildDirectory.appendingPathComponent("index.html").path) else {
            throw CocoaError(.fileNoSuchFile, userInfo: [NSLocalizedDescriptionKey: "Ignite did not generate index.html."])
        }
        let apiDirectory = buildDirectory.appendingPathComponent("s5", isDirectory: true)
        try FileManager.default.createDirectory(at: apiDirectory, withIntermediateDirectories: true)
        guard let runtime = Bundle.module.url(forResource: "runtime", withExtension: "mjs") else {
            throw CocoaError(.fileNoSuchFile)
        }
        try Data(contentsOf: runtime).write(to: apiDirectory.appendingPathComponent("runtime.mjs"), options: .atomic)
        let routes = String(decoding: try api.json(), as: UTF8.self)
        let client = """
        // Generated from Swift Endpoint definitions. Do not edit.
        import { createClient } from './runtime.mjs';
        export const api = createClient(\(routes));
        """
        try Data(client.utf8).write(to: apiDirectory.appendingPathComponent("client.mjs"), options: .atomic)
    }
}
