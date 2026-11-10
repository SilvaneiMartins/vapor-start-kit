import Fluent
import Vapor

func routes(_ app: Application) throws {
  let api = app.grouped("api", "v1")
  try api.register(
    collection: HealthController(readiness: DatabaseReadinessCheck(database: app.db)))
}
