import Fluent
import Vapor

func registerMigrations(_ app: Application) {
  // Apply explicitly with `swift run App migrate`, never during server startup.
  app.migrations.add(CreateUsers())
}
