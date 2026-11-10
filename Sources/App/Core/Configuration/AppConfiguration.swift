import Foundation
import Vapor

struct ConfigurationError: Error, CustomStringConvertible {
  let description: String
}

struct AppConfiguration: Sendable {
  let name: String
  let host: String
  let port: Int
  let databasePath: String?
  let logLevel: Logger.Level

  static func load(
    environment: Environment,
    get: (String) -> String? = { Environment.get($0) }
  ) throws -> Self {
    // Tests must never consume developer database paths or dotenv settings.
    if environment == .testing {
      return .init(
        name: "Vapor Starter Kit", host: "127.0.0.1", port: 8080,
        databasePath: nil, logLevel: .warning)
    }

    guard ["development", "production"].contains(environment.name) else {
      throw ConfigurationError(description: "Unsupported application environment")
    }

    if let declaredEnvironment = get("APP_ENV"), declaredEnvironment != environment.name {
      throw ConfigurationError(description: "APP_ENV must match --env or VAPOR_ENV")
    }

    guard get("DATABASE_DRIVER") ?? "sqlite" == "sqlite" else {
      throw ConfigurationError(description: "DATABASE_DRIVER must be sqlite")
    }

    let name = get("APP_NAME") ?? "Vapor Starter Kit"
    let host = get("APP_HOST") ?? "127.0.0.1"
    let rawPort = get("APP_PORT") ?? "8080"

    guard let port = Int(rawPort), (1...65535).contains(port) else {
      throw ConfigurationError(description: "APP_PORT must be an integer between 1 and 65535")
    }

    guard let level = Logger.Level(rawValue: get("LOG_LEVEL") ?? "info") else {
      throw ConfigurationError(description: "LOG_LEVEL is invalid")
    }

    if environment == .production, get("DATABASE_PATH") == nil {
      throw ConfigurationError(description: "DATABASE_PATH is required in production")
    }

    let path = get("DATABASE_PATH") ?? "./data/vapor.sqlite"

    guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      path != ":memory:", !path.hasPrefix("file:")
    else {
      throw ConfigurationError(
        description:
          "APP_NAME, APP_HOST and DATABASE_PATH must be valid nonempty values; use a filesystem path"
      )
    }

    return .init(name: name, host: host, port: port, databasePath: path, logLevel: level)
  }
}
