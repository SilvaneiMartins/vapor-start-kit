import Fluent

struct CreateUsers: AsyncMigration {
  func prepare(on database: any Database) async throws {
    try await database.schema(UserModel.schema)
      .id()
      .field("name", .string, .required)
      .field("email", .string, .required)
      .field("password_hash", .string, .required)
      .field("is_active", .bool, .required)
      .field("role", .string, .required)
      .field("created_at", .datetime, .required)
      .field("updated_at", .datetime, .required)
      .unique(on: "email", name: "users_email_unique")
      .create()
  }

  func revert(on database: any Database) async throws {
    try await database.schema(UserModel.schema).delete()
  }
}
