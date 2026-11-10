import Foundation
import Vapor

struct UserResponse: Content {
    let id: UUID
    let name: String
    let email: String
    let isActive: Bool
    let createdAt: Date
    let updatedAt: Date

    init(_ user: User) {
        id = user.id
        name = user.name
        email = user.email
        isActive = user.isActive
        createdAt = user.createdAt
        updatedAt = user.updatedAt
    }
}

struct UpdateUserRequest: Content {
    let name: String?
    let email: String?
}

struct UserListQuery: Decodable {
    let page: Int?
    let perPage: Int?
}

struct UserPageResponse: Content {
    let items: [UserResponse]
    let metadata: Metadata

    struct Metadata: Content {
        let page: Int
        let perPage: Int
        let total: Int
    }

    init(_ page: UserPage) {
        items = page.items.map(UserResponse.init)
        metadata = .init(page: page.pagination.page, perPage: page.pagination.perPage, total: page.total)
    }
}
