import Foundation
import S5

public struct Note: Codable, Sendable, Identifiable {
    public let id: UUID
    public let text: String
    public let completed: Bool
    public let createdAt: Date

    public init(id: UUID, text: String, completed: Bool, createdAt: Date) {
        self.id = id
        self.text = text
        self.completed = completed
        self.createdAt = createdAt
    }
}

public enum NotesAPI {
    public enum List: Endpoint {
        public typealias Input = Empty
        public typealias Output = [Note]
        public static let name = "notes.list"
    }

    public enum Create: Endpoint {
        public struct Input: Codable, Sendable {
            public let text: String
            public init(text: String) { self.text = text }
        }
        public typealias Output = Note
        public static let name = "notes.create"
        public static func validate(_ input: Input) throws {
            let text = input.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard (1...280).contains(text.count) else {
                throw APIError.invalidInput("Write between 1 and 280 characters.")
            }
        }
    }

    public enum SetCompleted: Endpoint {
        public struct Input: Codable, Sendable {
            public let id: UUID
            public let completed: Bool
            public init(id: UUID, completed: Bool) {
                self.id = id
                self.completed = completed
            }
        }
        public typealias Output = Note
        public static let name = "notes.set-completed"
    }

    public enum Delete: Endpoint {
        public struct Input: Codable, Sendable {
            public let id: UUID
            public init(id: UUID) { self.id = id }
        }
        public typealias Output = Empty
        public static let name = "notes.delete"
    }

    public static func catalog() throws -> EndpointCatalog {
        var catalog = EndpointCatalog()
        try catalog.register(List.self, as: "listNotes")
        try catalog.register(Create.self, as: "createNote")
        try catalog.register(SetCompleted.self, as: "setCompleted")
        try catalog.register(Delete.self, as: "deleteNote")
        return catalog
    }
}
