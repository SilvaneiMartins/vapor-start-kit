import Foundation
import Fluent
import Testing
import VaporTesting
@testable import App

@Suite("SQLite integration")
struct DatabaseTests {
    @Test func separateApplicationsHaveIndependentDatabases() async throws {
        try await withApp(configure: configure) { first in
            try await first.db.schema(Probe.schema).id().field("value", .string, .required).create()
            try await Probe(value: "first").save(on: first.db)
            try await withApp(configure: configure) { second in
                try await second.db.schema(Probe.schema).id().field("value", .string, .required).create()
                #expect(try await Probe.query(on: second.db).count() == 0)
            }
            #expect(try await Probe.query(on: first.db).count() == 1)
        }
    }

    @Test func fileDatabaseSurvivesApplicationRestart() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        // Only this test's exclusively owned temporary directory is removed.
        defer { try? FileManager.default.removeItem(at: directory) }
        let config = AppConfiguration(
            name: "Persistence Test", host: "127.0.0.1", port: 8080,
            databasePath: directory.appendingPathComponent("test.sqlite").path, logLevel: .warning
        )
        try await withApp(configure: { app in
            try configureDatabase(app, configuration: config)
        }) { app in
            try await app.db.schema(Probe.schema).id().field("value", .string, .required).create()
            try await Probe(value: "persistent").save(on: app.db)
        }
        try await withApp(configure: { app in
            try configureDatabase(app, configuration: config)
        }) { app in
            let record = try await Probe.query(on: app.db).first()
            #expect(record?.value == "persistent")
        }
    }
}

// Fluent property wrappers require unchecked Sendable; instances stay local to each operation.
private final class Probe: Model, @unchecked Sendable {
    static let schema = "test_probes"
    @ID(key: .id) var id: UUID?
    @Field(key: "value") var value: String

    init() {}
    init(value: String) { self.value = value }
}
