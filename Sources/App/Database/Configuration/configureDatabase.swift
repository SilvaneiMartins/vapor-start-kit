import Foundation
import Fluent
import FluentSQLiteDriver
import Vapor

func configureDatabase(_ app: Application, configuration: AppConfiguration) throws {
    let sqlite: SQLiteConfiguration
    if let path = configuration.databasePath {
        let url = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        sqlite = .init(storage: .file(path: url.path), enableForeignKeys: true)
    } else {
        // SQLiteKit assigns a unique identifier to each memory configuration.
        sqlite = .init(storage: .memory, enableForeignKeys: true)
    }
    // Disable SQL logging to avoid recording future query bindings containing secrets.
    app.databases.use(.sqlite(sqlite, sqlLogLevel: nil), as: .sqlite)
    registerMigrations(app)
}
