import AppContract
import Foundation
import S5
import ServerApp
import Testing
import Vapor
import VaporTesting

@Test func notebookLifecycleAndValidation() async throws {
    try await withApp(configure: { try await configure($0, inMemory: true) }) { app in
        let json = HTTPHeaders([("Content-Type", "application/json")])
        let created = try await app.sendRequest(.POST, "/api/v1/notes.create", headers: json,
            body: ByteBuffer(data: WireCodec.encode(NotesAPI.Create.Input(text: "  First note  "))))
        #expect(created.status == .ok)
        let note = try WireCodec.decode(Note.self, from: Data(created.body.readableBytesView))
        #expect(note.text == "First note")

        let list = try await app.sendRequest(.POST, "/api/v1/notes.list", headers: json, body: ByteBuffer(string: "{}"))
        #expect(try WireCodec.decode([Note].self, from: Data(list.body.readableBytesView)).count == 1)

        let updated = try await app.sendRequest(.POST, "/api/v1/notes.set-completed", headers: json,
            body: ByteBuffer(data: WireCodec.encode(NotesAPI.SetCompleted.Input(id: note.id, completed: true))))
        #expect(updated.status == .ok)
        #expect(try WireCodec.decode(Note.self, from: Data(updated.body.readableBytesView)).completed)

        let deleted = try await app.sendRequest(.POST, "/api/v1/notes.delete", headers: json,
            body: ByteBuffer(data: WireCodec.encode(NotesAPI.Delete.Input(id: note.id))))
        #expect(deleted.status == .ok)
        let absent = try await app.sendRequest(.POST, "/api/v1/notes.delete", headers: json,
            body: ByteBuffer(data: WireCodec.encode(NotesAPI.Delete.Input(id: note.id))))
        #expect(absent.status == .notFound)

        for text in ["   ", String(repeating: "x", count: 281)] {
            let invalid = try await app.sendRequest(.POST, "/api/v1/notes.create", headers: json,
                body: ByteBuffer(data: WireCodec.encode(NotesAPI.Create.Input(text: text))))
            #expect(invalid.status == .badRequest)
        }
        let final = try await app.sendRequest(.POST, "/api/v1/notes.list", headers: json, body: ByteBuffer(string: "{}"))
        #expect(try WireCodec.decode([Note].self, from: Data(final.body.readableBytesView)).isEmpty)
    }
}
