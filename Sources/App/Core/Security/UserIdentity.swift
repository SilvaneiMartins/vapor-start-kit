import Foundation
import Vapor

// Only trusted authentication middleware may populate this value.
// Roles and active status are always loaded from persistence by UserService.
struct UserIdentity: Authenticatable, Sendable {
  let userID: UUID
}
