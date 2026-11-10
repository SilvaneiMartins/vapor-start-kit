import Vapor

func configure(_ app: Application) async throws {
  let configuration = try AppConfiguration.load(environment: app.environment)
  app.logger.logLevel = configuration.logLevel
  app.http.server.configuration.hostname = configuration.host
  app.http.server.configuration.port = configuration.port
  app.routes.defaultMaxBodySize = "16kb"
  try configureDatabase(app, configuration: configuration)
  app.passwords.use(.bcrypt)
  try routes(app)
}
