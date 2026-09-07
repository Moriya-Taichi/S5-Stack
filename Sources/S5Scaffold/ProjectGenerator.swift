import Foundation

public enum GeneratorError: Error, CustomStringConvertible {
    case invalidName
    case destinationExists
    case invalidDependency
    case missingTemplate

    public var description: String {
        switch self {
        case .invalidName: "Use a project name starting with a letter, followed by ASCII letters or digits."
        case .destinationExists: "The destination already exists. Choose a new directory."
        case .invalidDependency: "Choose a local S5 package path or a full 40-character commit revision."
        case .missingTemplate: "The bundled starter template is missing. Rebuild the s5 executable."
        }
    }
}

public enum S5Dependency: Sendable {
    case local(URL)
    case revision(String)
    case main

    var declaration: String {
        get throws {
            switch self {
            case .local(let url):
                let path = url.standardizedFileURL.path
                guard FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path),
                      !path.contains("\n"), !path.contains("\r") else { throw GeneratorError.invalidDependency }
                let escaped = path.replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "\"", with: "\\\"")
                return ".package(name: \"S5\", path: \"\(escaped)\")"
            case .revision(let revision):
                guard revision.count == 40, revision.utf8.allSatisfy({
                    (48...57).contains($0) || (97...102).contains($0)
                }) else { throw GeneratorError.invalidDependency }
                return ".package(url: \"https://github.com/Moriya-Taichi/S5-Stack.git\", revision: \"\(revision)\")"
            case .main:
                return ".package(url: \"https://github.com/Moriya-Taichi/S5-Stack.git\", branch: \"main\")"
            }
        }
    }
}

public struct ProjectGenerator: Sendable {
    public init() {}

    /// Creates the project in a temporary sibling directory, then moves it into place.
    /// Existing projects are never merged or overwritten, including on partial failures.
    @discardableResult
    public func generate(name: String, in parent: URL, dependency: S5Dependency = .main) throws -> URL {
        guard let first = name.utf8.first,
              (65...90).contains(first) || (97...122).contains(first),
              name.utf8.allSatisfy({ (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) }) else {
            throw GeneratorError.invalidName
        }
        let declaration = try dependency.declaration
        let fm = FileManager.default
        let destination = parent.appendingPathComponent(name, isDirectory: true)
        guard !fm.fileExists(atPath: destination.path) else { throw GeneratorError.destinationExists }
        guard let template = Bundle.module.url(forResource: "Starter", withExtension: nil),
              let files = fm.enumerator(at: template, includingPropertiesForKeys: [.isRegularFileKey]) else {
            throw GeneratorError.missingTemplate
        }
        try fm.createDirectory(at: parent, withIntermediateDirectories: true)
        let staging = parent.appendingPathComponent(".s5-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: staging, withIntermediateDirectories: false)
        defer { try? fm.removeItem(at: staging) }
        for case let source as URL in files {
            guard try source.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else { continue }
            var relative = String(source.path.dropFirst(template.path.count + 1))
            if relative.hasSuffix(".template") { relative.removeLast(".template".count) }
            if relative == "gitignore" { relative = ".gitignore" }
            if relative == "dockerignore" { relative = ".dockerignore" }
            let target = staging.appendingPathComponent(relative)
            var contents = try String(contentsOf: source, encoding: .utf8)
            contents = contents.replacingOccurrences(of: "__PROJECT_NAME__", with: name)
                .replacingOccurrences(of: "__S5_DEPENDENCY__", with: declaration)
                .replacingOccurrences(of: "__S5_PACKAGE_ID__", with: {
                    if case .local = dependency { return "S5" }
                    return "S5-Stack"
                }())
            try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try contents.write(to: target, atomically: true, encoding: .utf8)
        }
        try fm.moveItem(at: staging, to: destination)
        return destination
    }
}
