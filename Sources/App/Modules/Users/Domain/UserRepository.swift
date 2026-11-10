import Foundation

protocol UserRepository: Sendable {
  func find(id: UUID) async throws -> User?
  func find(email: String) async throws -> User?
  func create(_ user: User) async throws -> User
  func list(_ pagination: UserPagination) async throws -> UserPage
  func updateProfile(id: UUID, name: String?, email: String?, at date: Date) async throws -> User
  func deactivate(id: UUID, at date: Date) async throws
}

protocol PasswordHashing: Sendable {
  func hash(_ password: String) async throws -> String
}
