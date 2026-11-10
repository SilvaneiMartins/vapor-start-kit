import Vapor

struct HealthResponse: Content {
  let status: String
  let service: String
  let version: String

  static let healthy = Self(status: "ok", service: "vapor-starter-kit", version: "1.0.0")
  static let unavailable = Self(
    status: "unavailable", service: "vapor-starter-kit", version: "1.0.0")
}

struct HealthController: RouteCollection {
  let readiness: any ReadinessChecking

  func boot(routes: any RoutesBuilder) throws {
    let health = routes.grouped("health")
    health.get { _ in HealthResponse.healthy }

    health.get("ready") { request async throws -> Response in
      do {
        try await readiness.check()
        return try await HealthResponse.healthy.encodeResponse(for: request)
      } catch {
        // Dependency errors may contain filesystem paths; never expose or log them here.
        return try await HealthResponse.unavailable.encodeResponse(
          status: .serviceUnavailable, for: request
        )
      }
    }
  }
}
