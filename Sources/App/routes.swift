import Fluent
import Vapor

func routes(_ app: Application) throws {
    let api = app.grouped("api", "v1")
    try api.register(collection: HealthController(readiness: DatabaseReadinessCheck(database: app.db)))
    let users = UserService(
        repository: FluentUserRepository(database: app.db),
        passwordHasher: VaporPasswordHasher(hasher: app.password.async)
    )
    try api.register(collection: UserController(service: users))
}
