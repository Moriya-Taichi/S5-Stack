import AppContract
import Fluent
import FluentPostgresDriver
import FluentSQLiteDriver
import Foundation
import S5
import S5Vapor
import Vapor

/// The starter is a public, shared notebook. Add Vapor authentication middleware and ownership
/// checks to these routes before adapting it to private, per-user data.
public func configure(_ app: Application, inMemory: Bool = false) async throws {
    app.routes.defaultMaxBodySize = "64kb"
    app.middleware.use(EndpointErrorMiddleware())
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory, defaultFile: "index.html"))

    if inMemory {
        app.databases.use(.sqlite(.memory), as: .sqlite)
    } else if let url = Environment.get("DATABASE_URL"), !url.isEmpty {
        try app.databases.use(.postgres(url: url), as: .psql)
    } else {
        let path = Environment.get("DATABASE_PATH") ?? "db.sqlite"
        app.databases.use(.sqlite(.file(path)), as: .sqlite)
    }
    app.migrations.add(CreateNotes())
    if inMemory || app.environment == .development {
        try await app.autoMigrate()
    }

    app.get("health") { ["status": "ok"] }
    app.get("ready") { request async throws -> [String: String] in
        _ = try await NoteRecord.query(on: request.db).count()
        return ["status": "ready"]
    }

    try app.endpoint(NotesAPI.List.self) { _, request in
        try await NoteRecord.query(on: request.db)
            .sort(\.$createdAt, .descending).range(..<100).all().map { try $0.dto() }
    }
    try app.endpoint(NotesAPI.Create.self) { input, request in
        let note = NoteRecord(text: input.text.trimmingCharacters(in: .whitespacesAndNewlines))
        try await note.save(on: request.db)
        return try note.dto()
    }
    try app.endpoint(NotesAPI.SetCompleted.self) { input, request in
        guard let note = try await NoteRecord.find(input.id, on: request.db) else { throw APIError.notFound() }
        note.completed = input.completed
        try await note.update(on: request.db)
        return try note.dto()
    }
    try app.endpoint(NotesAPI.Delete.self) { input, request in
        guard let note = try await NoteRecord.find(input.id, on: request.db) else { throw APIError.notFound() }
        try await note.delete(on: request.db)
        return Empty()
    }
}
