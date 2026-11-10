import Foundation
import Vapor

struct UserController: RouteCollection {
  let service: UserService

  func boot(routes: any RoutesBuilder) throws {
    let users = routes.grouped("users")
      .grouped(UserErrorMiddleware())
      .grouped(
        UserIdentity.guardMiddleware(
          throwing: Abort(.unauthorized, reason: "Authentication required")))

    users.get { request async throws -> UserPageResponse in
      let actor = try request.auth.require(UserIdentity.self)
      let query = try request.query.decode(UserListQuery.self)
      let pagination = try UserPagination(page: query.page ?? 1, perPage: query.perPage ?? 20)

      return try await UserPageResponse(service.list(actorID: actor.userID, pagination: pagination))
    }
    users.get(":userID") { request async throws -> UserResponse in
      let actor = try request.auth.require(UserIdentity.self)

      return try await UserResponse(service.profile(id: userID(request), actorID: actor.userID))
    }
    users.patch(":userID") { request async throws -> UserResponse in
      let actor = try request.auth.require(UserIdentity.self)
      let input = try request.content.decode(UpdateUserRequest.self)

      return try await UserResponse(
        service.updateProfile(
          id: userID(request), actorID: actor.userID, name: input.name, email: input.email
        ))
    }
    users.delete(":userID") { request async throws -> HTTPStatus in
      let actor = try request.auth.require(UserIdentity.self)
      try await service.deactivate(id: userID(request), actorID: actor.userID)

      return .noContent
    }
  }

  private func userID(_ request: Request) throws -> UUID {
    guard let raw = request.parameters.get("userID"), let id = UUID(uuidString: raw) else {
      throw Abort(.badRequest, reason: "userID must be a UUID")
    }

    return id
  }
}
