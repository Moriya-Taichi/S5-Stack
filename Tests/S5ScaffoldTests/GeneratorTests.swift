import Foundation
import S5Scaffold
import Testing

@Test func generatesAnIndependentProjectAndRefusesOverwrite() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let generator = ProjectGenerator()
    let project = try generator.generate(name: "Fieldnotes", in: directory, dependency: .revision(String(repeating: "a", count: 40)))
    let manifest = try String(contentsOf: project.appendingPathComponent("Package.swift"), encoding: .utf8)
    #expect(manifest.contains("Fieldnotes"))
    #expect(!manifest.contains("__S5_"))
    #expect(!manifest.contains("Nido"))
    #expect(FileManager.default.fileExists(atPath: project.appendingPathComponent(".gitignore").path))
    #expect(throws: GeneratorError.self) { try generator.generate(name: "Fieldnotes", in: directory) }
    #expect(try String(contentsOf: project.appendingPathComponent("Package.swift"), encoding: .utf8) == manifest)
    for name in ["../escape", "1App", "App-name", "App\nBad", ""] {
        #expect(throws: GeneratorError.self) { try generator.generate(name: name, in: directory) }
    }
}
