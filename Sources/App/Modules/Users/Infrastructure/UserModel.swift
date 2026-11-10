import Fluent
import Foundation

// Fluent wrappers require unchecked Sendable; model instances never leave this repository layer.
final class UserModel: Model, @unchecked Sendable {
  static let schema = "users"

  @ID(key: .id) var id: UUID?
  @Field(key: "name") var name: String
  @Field(key: "email") var email: String
  @Field(key: "password_hash") var passwordHash: String
  @Field(key: "is_active") var isActive: Bool
  @Field(key: "role") var role: String
  @Field(key: "created_at") var createdAt: Date
  @Field(key: "updated_at") var updatedAt: Date

  init() {}

  init(_ user: User) {
    id = user.id
    name = user.name
    email = user.email
    passwordHash = user.passwordHash
    isActive = user.isActive
    role = user.role.rawValue
    createdAt = user.createdAt
    updatedAt = user.updatedAt
  }

  func toDomain() throws -> User {
    guard let role = UserRole(rawValue: role) else { throw UserError.storageFailure }

    return try User(
      id: requireID(), name: name, email: email, passwordHash: passwordHash,
      isActive: isActive, role: role, createdAt: createdAt, updatedAt: updatedAt
    )
  }
}
