import Foundation

struct UserService: Sendable {
  let repository: any UserRepository
  let passwordHasher: any PasswordHashing
  var now: @Sendable () -> Date = { Date() }

  // Used internally by the future registration use case; never accepts a role from a client.
  func create(name: String, email: String, password: String) async throws -> User {
    let name = try UserInputRules.name(name)
    let email = try UserInputRules.email(email)
    try UserInputRules.password(password)
    guard try await repository.find(email: email) == nil else {
      throw UserError.emailAlreadyExists
    }
    let hash = try await passwordHasher.hash(password)
    let date = now()
    return try await repository.create(
      User(
        id: UUID(), name: name, email: email, passwordHash: hash,
        isActive: true, role: .member, createdAt: date, updatedAt: date
      ))
  }

  func profile(id: UUID, actorID: UUID) async throws -> User {
    let actor = try await activeActor(actorID)
    try authorize(actor, targetID: id)
    guard let user = try await repository.find(id: id) else { throw UserError.notFound }
    return user
  }

  func list(actorID: UUID, pagination: UserPagination) async throws -> UserPage {
    let actor = try await activeActor(actorID)
    guard actor.role == .admin else { throw UserError.forbidden }
    return try await repository.list(pagination)
  }

  func updateProfile(id: UUID, actorID: UUID, name: String?, email: String?) async throws -> User {
    let user = try await profile(id: id, actorID: actorID)
    guard user.isActive else { throw UserError.forbidden }
    guard name != nil || email != nil else {
      throw UserError.invalidInput("Provide at least one profile field")
    }
    let name = try name.map(UserInputRules.name)
    let email = try email.map(UserInputRules.email)
    return try await repository.updateProfile(id: id, name: name, email: email, at: now())
  }

  func deactivate(id: UUID, actorID: UUID) async throws {
    _ = try await profile(id: id, actorID: actorID)
    try await repository.deactivate(id: id, at: now())
  }

  private func activeActor(_ id: UUID) async throws -> User {
    guard let actor = try await repository.find(id: id), actor.isActive else {
      throw UserError.unauthenticated
    }
    return actor
  }

  private func authorize(_ actor: User, targetID: UUID) throws {
    guard actor.id == targetID || actor.role == .admin else { throw UserError.forbidden }
  }
}
