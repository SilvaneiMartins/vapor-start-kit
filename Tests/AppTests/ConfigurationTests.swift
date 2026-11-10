import Testing
import Vapor
@testable import App

@Suite("Application configuration")
struct ConfigurationTests {
    @Test func developmentUsesLocalDefaults() throws {
        let config = try AppConfiguration.load(environment: .development, get: { _ in nil })
        #expect(config.host == "127.0.0.1")
        #expect(config.port == 8080)
        #expect(config.databasePath == "./data/vapor.sqlite")
    }

    @Test func testingIgnoresExternalConfiguration() throws {
        let config = try AppConfiguration.load(environment: .testing, get: { _ in
            Issue.record("Testing must not read process configuration")
            return "./data/vapor.sqlite"
        })
        #expect(config.databasePath == nil)
    }

    @Test(arguments: ["", "abc", "0", "65536", "-1"])
    func invalidPortsAreRejected(port: String) {
        #expect(throws: ConfigurationError.self) {
            try AppConfiguration.load(environment: .development, get: { $0 == "APP_PORT" ? port : nil })
        }
    }

    @Test func productionRequiresExplicitDatabasePath() {
        #expect(throws: ConfigurationError.self) {
            try AppConfiguration.load(environment: .production, get: { _ in nil })
        }
    }

    @Test func mismatchedEnvironmentIsRejected() {
        #expect(throws: ConfigurationError.self) {
            try AppConfiguration.load(environment: .production, get: { $0 == "APP_ENV" ? "development" : nil })
        }
    }

    @Test(arguments: ["DATABASE_DRIVER", "LOG_LEVEL", "DATABASE_PATH", "APP_HOST", "APP_NAME"])
    func invalidSettingsAreRejected(key: String) {
        #expect(throws: ConfigurationError.self) {
            try AppConfiguration.load(environment: .development, get: { $0 == key ? "" : nil })
        }
    }
}
