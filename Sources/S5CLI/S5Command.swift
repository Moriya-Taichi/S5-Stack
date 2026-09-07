import ArgumentParser
import Foundation
import S5Scaffold

@main
struct S5Command: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "s5", abstract: "Build Swift web applications with Ignite and Vapor.",
        version: "0.1.0-dev", subcommands: [New.self, Build.self, Dev.self])
}

struct New: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Create an Ignite + Vapor + Fluent application.")
    @Argument(help: "Project name, such as MyApp.") var name: String
    @Option(help: "Parent directory for the new project.") var directory = "."
    @Option(name: .customLong("s5-path"), help: "Use a local S5 checkout.") var s5Path: String?
    @Option(help: "Pin S5 to a full Git commit SHA; otherwise use main.") var revision: String?

    func validate() throws {
        if s5Path != nil && revision != nil { throw ValidationError("Use either --s5-path or --revision.") }
    }

    func run() throws {
        let dependency: S5Dependency
        if let s5Path { dependency = .local(URL(fileURLWithPath: s5Path)) }
        else if let revision { dependency = .revision(revision) }
        else { dependency = .main }
        let project = try ProjectGenerator().generate(name: name, in: URL(fileURLWithPath: directory), dependency: dependency)
        print("Created \(project.path)\nOpen its Package.swift, or run s5 dev from that directory.")
    }
}

struct Build: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Build Ignite assets and the Vapor executable.")
    @Option(help: "Generated application directory.") var directory = "."
    @Flag(help: "Build optimized binaries.") var release = false

    func run() throws {
        let root = try applicationDirectory(directory)
        let configuration = release ? "release" : "debug"
        try execute(["run", "-c", configuration, "Frontend"], in: root)
        try execute(["build", "-c", configuration, "--product", "Server"], in: root)
    }
}

struct Dev: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Build the frontend, then serve the app locally. Restart after edits.")
    @Option(help: "Generated application directory.") var directory = "."
    @Option(help: "Listen hostname.") var hostname = "127.0.0.1"
    @Option(help: "Listen port.") var port: Int = 8080

    func validate() throws {
        guard (1...65535).contains(port) else { throw ValidationError("Port must be between 1 and 65535.") }
    }

    func run() throws {
        let root = try applicationDirectory(directory)
        try execute(["run", "Frontend"], in: root)
        try execute(["run", "Server", "serve", "--hostname", hostname, "--port", String(port)], in: root)
    }
}

private func applicationDirectory(_ path: String) throws -> URL {
    let root = URL(fileURLWithPath: path).standardizedFileURL
    guard FileManager.default.fileExists(atPath: root.appendingPathComponent("s5.json").path) else {
        throw ValidationError("Run this command inside an application created with s5 new, or pass --directory.")
    }
    return root
}

private func execute(_ arguments: [String], in directory: URL) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["swift"] + arguments
    process.currentDirectoryURL = directory
    process.standardInput = FileHandle.standardInput
    process.standardOutput = FileHandle.standardOutput
    process.standardError = FileHandle.standardError
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else { throw ExitCode(process.terminationStatus) }
}
