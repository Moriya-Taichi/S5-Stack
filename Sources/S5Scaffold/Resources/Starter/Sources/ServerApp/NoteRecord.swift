import AppContract
import Fluent
import Foundation
import Vapor

/// Fluent's mutable model stays on the server; only the Note DTO crosses the API boundary.
final class NoteRecord: Model, @unchecked Sendable {
    static let schema = "notes"
    @ID(key: .id) var id: UUID?
    @Field(key: "text") var text: String
    @Field(key: "completed") var completed: Bool
    @Timestamp(key: "created_at", on: .create) var createdAt: Date?

    init() {}

    init(text: String) {
        self.text = text
        self.completed = false
    }

    func dto() throws -> Note {
        guard let createdAt else { throw Abort(.internalServerError) }
        return try Note(id: requireID(), text: text, completed: completed, createdAt: createdAt)
    }
}

struct CreateNotes: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(NoteRecord.schema)
            .id()
            .field("text", .string, .required)
            .field("completed", .bool, .required)
            .field("created_at", .datetime, .required)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(NoteRecord.schema).delete()
    }
}
