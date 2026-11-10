import Foundation

enum UserRole: String, Sendable {
  case member
  case admin
}

// Internal domain value; intentionally not Codable or HTTP Content.
struct User: Sendable {
  let id: UUID
  let name: String
  let email: String
  let passwordHash: String
  let isActive: Bool
  let role: UserRole
  let createdAt: Date
  let updatedAt: Date
}

enum UserError: Error, Equatable {
  case invalidInput(String)
  case emailAlreadyExists
  case notFound
  case unauthenticated
  case forbidden
  case storageFailure
}

struct UserPagination: Sendable {
  let page: Int
  let perPage: Int
  var offset: Int { (page - 1) * perPage }

  init(page: Int = 1, perPage: Int = 20) throws {
    guard (1...1_000_000).contains(page), (1...100).contains(perPage) else {
      throw UserError.invalidInput("page must be 1...1000000 and perPage must be 1...100")
    }
    self.page = page
    self.perPage = perPage
  }
}

struct UserPage: Sendable {
  let items: [User]
  let total: Int
  let pagination: UserPagination
}
