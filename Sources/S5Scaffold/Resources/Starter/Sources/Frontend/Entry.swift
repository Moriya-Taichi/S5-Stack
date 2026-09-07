import AppContract
import Foundation
import Ignite
import S5Ignite

@main @MainActor
struct Frontend {
    static func main() async throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let siteURL = ProcessInfo.processInfo.environment["SITE_URL"] ?? "http://localhost:8080"
        guard let url = URL(string: siteURL), let scheme = url.scheme,
              ["http", "https"].contains(scheme), url.host != nil else { throw URLError(.badURL) }
        var site = NotesSite(url: url)
        try await site.publish(api: NotesAPI.catalog(), sourceDirectory: root,
                               buildDirectory: root.appendingPathComponent("Public"))
    }
}

struct NotesSite: Site {
    var name = "__PROJECT_NAME__"
    var url: URL
    var homePage = Home()
    var layout = MainLayout()
}

struct MainLayout: Layout {
    var body: some Document {
        Head {
            MetaLink(href: "/app.css", rel: "stylesheet")
        }
        Body {
            content
            Script(file: "/app.mjs").type(value: "module")
        }
    }
}

struct Home: StaticPage {
    var title = "Fieldnotes"

    var body: some HTML {
        Tag("main") {
            Tag("header") {
                Text("FIELDNOTES").class("eyebrow")
                Text("A little space for your next idea.").font(.title1)
                Text("A shared notebook. Capture something, mark it done, make room for what comes next.")
                    .class("intro")
            }
            Section {
                Form {
                    TextField("Your note", prompt: "What’s on your mind?")
                        .id("note-text").required()
                    Button("Add note").type(.submit).id("add-note")
                }
                .id("note-form")
                Text("280 characters · shared with everyone using this notebook").class("hint")
            }
            .class("composer")
            Text("Loading notes…").id("status").customAttribute(name: "role", value: "status")
            Tag("ul").id("notes").class("notes").customAttribute(name: "aria-label", value: "Notes")
            Tag("footer") {
                Text("Made with S5 Stack").class("hint")
            }
        }
        .class("notebook")
    }
}
