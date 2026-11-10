import Testing
import VaporTesting
@testable import App

@Suite("Health endpoints")
struct HealthTests {
    @Test func healthReturnsPublicMetadata() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.GET, "/api/v1/health") { response async throws in
                #expect(response.status == .ok)
                let body = try response.content.decode(HealthResponse.self)
                #expect(body.status == "ok")
                #expect(body.service == "vapor-starter-kit")
                #expect(body.version == "1.0.0")
            }
        }
    }

    @Test func readinessConnectsToIsolatedSQLite() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.GET, "/api/v1/health/ready") { response async throws in
                #expect(response.status == .ok)
                #expect(try response.content.decode(HealthResponse.self).status == "ok")
            }
        }
    }

    @Test func readinessHidesDependencyFailures() async throws {
        try await withApp(configure: { app in
            try app.grouped("api", "v1").register(
                collection: HealthController(readiness: UnavailableDatabase())
            )
        }) { app in
            try await app.testing().test(.GET, "/api/v1/health/ready") { response async throws in
                #expect(response.status == .serviceUnavailable)
                #expect(try response.content.decode(HealthResponse.self).status == "unavailable")
                #expect(!response.body.string.contains("private"))
            }
            try await app.testing().test(.GET, "/api/v1/health") { response async in
                #expect(response.status == .ok)
            }
        }
    }
}

private struct UnavailableDatabase: ReadinessChecking {
    func check() async throws {
        throw ConfigurationError(description: "Database failed at /private/internal.sqlite")
    }
}
