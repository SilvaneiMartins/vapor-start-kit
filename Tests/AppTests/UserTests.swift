import Foundation
import Fluent
import Testing
import VaporTesting
@testable import App

@Suite("Users module", .serialized)
struct UserTests {
    @Test func creationNormalizesEmailAndHashesPassword() async throws {
        try await withUsers { app, service async throws in
            let user = try await service.create(name: "  Alice Example  ", email: "  ALICE@Example.COM ", password: testPassword)
            #expect(user.name == "Alice Example")
            #expect(user.email == "alice@example.com")
            #expect(user.role == .member)
            #expect(user.isActive)
            let model = try #require(try await UserModel.find(user.id, on: app.db))
            #expect(model.passwordHash != testPassword)
            #expect(try await app.password.async.verify(testPassword, created: model.passwordHash))
            #expect(model.createdAt == model.updatedAt)
        }
    }

    @Test func duplicateNormalizedEmailIsRejectedByServiceAndDatabase() async throws {
        try await withUsers { app, service async throws in
            let user = try await service.create(name: "Alice Example", email: "alice@example.com", password: testPassword)
            await #expect(throws: UserError.emailAlreadyExists) {
                try await service.create(name: "Other Name", email: " ALICE@EXAMPLE.COM ", password: testPassword)
            }
            // Bypass the service and repository to verify the actual database unique constraint.
            let duplicate = UserModel(user)
            duplicate.id = UUID()
            await #expect(throws: (any Error).self) { try await duplicate.create(on: app.db) }
            #expect(try await UserModel.query(on: app.db).count() == 1)
        }
    }

    @Test func repositoryHandlesDuplicateAfterPreflightCheck() async throws {
        try await withUsers { app, service async throws in
            let user = try await service.create(name: "Alice Example", email: "alice@example.com", password: testPassword)
            let duplicate = User(id: UUID(), name: user.name, email: " ALICE@EXAMPLE.COM ",
                                 passwordHash: user.passwordHash, isActive: true, role: .member,
                                 createdAt: user.createdAt, updatedAt: user.updatedAt)
            await #expect(throws: UserError.emailAlreadyExists) {
                try await FluentUserRepository(database: app.db).create(duplicate)
            }
        }
    }

    @Test func invalidCreationDoesNotPersistAnything() async throws {
        try await withUsers { app, service async throws in
            await #expect(throws: UserError.self) {
                try await service.create(name: "A", email: "invalid", password: "short")
            }
            #expect(try await UserModel.query(on: app.db).count() == 0)
        }
    }

    @Test func anonymousRoutesRejectAccessIncludingForgedHeaders() async throws {
        try await withUsers { app, _ async throws in
            let path = "/api/v1/users/\(UUID())"
            for method in [HTTPMethod.GET, .PATCH, .DELETE] {
                try await app.testing().test(method, path, beforeRequest: { request in
                    request.headers.bearerAuthorization = .init(token: "forged")
                    request.headers.add(name: "X-User-ID", value: UUID().uuidString)
                    request.headers.add(name: "X-Role", value: "admin")
                }, afterResponse: { response async in
                    #expect(response.status == .unauthorized)
                })
            }
            try await app.testing().test(.GET, "/api/v1/users") { response async in
                #expect(response.status == .unauthorized)
            }
        }
    }

    @Test func ownerCanReadProfileWithoutCredentialFields() async throws {
        try await withUsers { app, service async throws in
            let user = try await createMember(service)
            authenticate(user.id, in: app)
            try await app.testing().test(.GET, "/api/v1/users/\(user.id)") { response async throws in
                #expect(response.status == .ok)
                #expect(try response.content.decode(UserResponse.self).id == user.id)
                #expect(!response.body.string.contains("password"))
                #expect(!response.body.string.contains(user.passwordHash))
                #expect(!response.body.string.contains("role"))
            }
        }
    }

    @Test func memberCannotReadChangeOrDeactivateAnotherUser() async throws {
        try await withUsers { app, service async throws in
            let owner = try await createMember(service)
            let other = try await service.create(name: "Other User", email: "other@example.com", password: testPassword)
            authenticate(owner.id, in: app)
            for method in [HTTPMethod.GET, .PATCH, .DELETE] {
                try await app.testing().test(method, "/api/v1/users/\(other.id)", beforeRequest: { request in
                    if method == .PATCH { try request.content.encode(UpdateUserRequest(name: "Changed Name", email: nil)) }
                }, afterResponse: { response async in
                    #expect(response.status == .forbidden)
                })
            }
            let unchanged = try #require(try await UserModel.find(other.id, on: app.db))
            #expect(unchanged.name == "Other User")
            #expect(unchanged.isActive)
            try await app.testing().test(.GET, "/api/v1/users") { response async in
                #expect(response.status == .forbidden)
            }
        }
    }

    @Test func profileUpdateIgnoresPrivilegeAndCredentialFields() async throws {
        try await withUsers { app, service async throws in
            let user = try await createMember(service)
            authenticate(user.id, in: app)
            try await app.testing().test(.PATCH, "/api/v1/users/\(user.id)", beforeRequest: { request in
                try request.content.encode([
                    "name": " Updated Name ", "email": " UPDATED@EXAMPLE.COM ",
                    "role": "admin", "passwordHash": "attacker-value", "isActive": "false"
                ])
            }, afterResponse: { response async throws in
                #expect(response.status == .ok)
                let body = try response.content.decode(UserResponse.self)
                #expect(body.name == "Updated Name")
                #expect(body.email == "updated@example.com")
            })
            let stored = try #require(try await UserModel.find(user.id, on: app.db))
            #expect(stored.passwordHash == user.passwordHash)
            #expect(stored.role == "member")
            #expect(stored.isActive)
            #expect(stored.createdAt == user.createdAt)
            #expect(stored.updatedAt >= stored.createdAt)
        }
    }

    @Test func duplicateUpdateReturnsConflictAndPreservesProfile() async throws {
        try await withUsers { app, service async throws in
            let user = try await createMember(service)
            _ = try await service.create(name: "Other User", email: "other@example.com", password: testPassword)
            authenticate(user.id, in: app)
            try await app.testing().test(.PATCH, "/api/v1/users/\(user.id)", beforeRequest: { request in
                try request.content.encode(UpdateUserRequest(name: "Changed Name", email: " OTHER@EXAMPLE.COM "))
            }, afterResponse: { response async in
                #expect(response.status == .conflict)
                #expect(!response.body.string.contains("UNIQUE"))
            })
            let stored = try #require(try await UserModel.find(user.id, on: app.db))
            #expect(stored.name == user.name)
            #expect(stored.email == user.email)
        }
    }

    @Test func emptyAndInvalidProfilesReturnBadRequest() async throws {
        try await withUsers { app, service async throws in
            let user = try await createMember(service)
            authenticate(user.id, in: app)
            for input in [UpdateUserRequest(name: nil, email: nil), .init(name: "A", email: nil), .init(name: nil, email: "bad")] {
                try await app.testing().test(.PATCH, "/api/v1/users/\(user.id)", beforeRequest: { request in
                    try request.content.encode(input)
                }, afterResponse: { response async in
                    #expect(response.status == .badRequest)
                })
            }
        }
    }

    @Test func deactivationPreservesRowAndPreventsFurtherAccess() async throws {
        try await withUsers { app, service async throws in
            let user = try await createMember(service)
            authenticate(user.id, in: app)
            try await app.testing().test(.DELETE, "/api/v1/users/\(user.id)") { response async in
                #expect(response.status == .noContent)
                #expect(response.body.readableBytes == 0)
            }
            let stored = try #require(try await UserModel.find(user.id, on: app.db))
            #expect(!stored.isActive)
            #expect(stored.passwordHash == user.passwordHash)
            try await app.testing().test(.GET, "/api/v1/users/\(user.id)") { response async in
                #expect(response.status == .unauthorized)
            }
            await #expect(throws: UserError.emailAlreadyExists) {
                try await service.create(name: "Replacement", email: user.email, password: testPassword)
            }
        }
    }

    @Test func administratorCanManageOtherAccountsAndPaginate() async throws {
        try await withUsers { app, service async throws in
            let admin = try await createMember(service)
            let other = try await service.create(name: "Other User", email: "other@example.com", password: testPassword)
            try await promoteForTest(admin.id, on: app)
            authenticate(admin.id, in: app)
            try await app.testing().test(.GET, "/api/v1/users?page=1&perPage=1") { response async throws in
                #expect(response.status == .ok)
                let page = try response.content.decode(UserPageResponse.self)
                #expect(page.items.count == 1)
                #expect(page.items.first?.id == admin.id)
                #expect(page.metadata.total == 2)
                #expect(page.metadata.page == 1)
                #expect(page.metadata.perPage == 1)
                #expect(!response.body.string.contains("password"))
            }
            try await app.testing().test(.GET, "/api/v1/users?page=2&perPage=1") { response async throws in
                #expect(try response.content.decode(UserPageResponse.self).items.first?.id == other.id)
            }
            try await app.testing().test(.GET, "/api/v1/users?page=3&perPage=1") { response async throws in
                #expect(try response.content.decode(UserPageResponse.self).items.isEmpty == true)
            }
            try await app.testing().test(.GET, "/api/v1/users/\(other.id)") { response async in
                #expect(response.status == .ok)
            }
            try await app.testing().test(.PATCH, "/api/v1/users/\(other.id)", beforeRequest: { request in
                try request.content.encode(UpdateUserRequest(name: "Admin Updated", email: nil))
            }, afterResponse: { response async in
                #expect(response.status == .ok)
            })
            try await app.testing().test(.DELETE, "/api/v1/users/\(other.id)") { response async in
                #expect(response.status == .noContent)
            }
            try await app.testing().test(.GET, "/api/v1/users") { response async throws in
                let page = try response.content.decode(UserPageResponse.self)
                #expect(page.metadata.total == 2)
                #expect(page.items.first(where: { $0.id == other.id })?.isActive == false)
            }
        }
    }

    @Test func authorizationReloadsRoleAndActiveStatus() async throws {
        try await withUsers { app, service async throws in
            let admin = try await createMember(service)
            try await promoteForTest(admin.id, on: app)
            authenticate(admin.id, in: app)
            try await app.testing().test(.GET, "/api/v1/users") { response async in
                #expect(response.status == .ok)
            }
            try await UserModel.query(on: app.db).filter(\.$id == admin.id).set(\.$role, to: "member").update()
            try await app.testing().test(.GET, "/api/v1/users") { response async in
                #expect(response.status == .forbidden)
            }
            try await UserModel.query(on: app.db).filter(\.$id == admin.id).set(\.$isActive, to: false).update()
            try await app.testing().test(.GET, "/api/v1/users") { response async in
                #expect(response.status == .unauthorized)
            }
        }
    }

    @Test func invalidIDsAndPaginationAreRejected() async throws {
        try await withUsers { app, service async throws in
            let admin = try await createMember(service)
            try await promoteForTest(admin.id, on: app)
            authenticate(admin.id, in: app)
            for suffix in ["/invalid", "?page=0", "?perPage=101", "?page=abc", "?page=9999999999999999999999999"] {
                try await app.testing().test(.GET, "/api/v1/users\(suffix)") { response async in
                    #expect(response.status == .badRequest)
                }
            }
            try await app.testing().test(.GET, "/api/v1/users/\(UUID())") { response async in
                #expect(response.status == .notFound)
            }
        }
    }

    @Test func serviceAuthorizationWorksWithoutHTTPMiddleware() async throws {
        try await withUsers { _, service async throws in
            let owner = try await createMember(service)
            await #expect(throws: UserError.forbidden) {
                try await service.profile(id: UUID(), actorID: owner.id)
            }
            await #expect(throws: UserError.forbidden) {
                try await service.list(actorID: owner.id, pagination: UserPagination())
            }
            await #expect(throws: UserError.unauthenticated) {
                try await service.profile(id: owner.id, actorID: UUID())
            }
        }
    }

    @Test func foreignKeysRejectReferencesToMissingUsers() async throws {
        try await withUsers { app, service async throws in
            try await app.db.schema(UserReference.schema).id()
                .field("user_id", .uuid, .required, .references("users", "id"))
                .create()
            let user = try await createMember(service)
            try await UserReference(userID: user.id).create(on: app.db)
            await #expect(throws: (any Error).self) {
                try await UserReference(userID: UUID()).create(on: app.db)
            }
            #expect(try await UserReference.query(on: app.db).count() == 1)
        }
    }

    @Test func databaseFailureDoesNotExposeSQLOrInternalPaths() async throws {
        // Intentionally omit migrations in this isolated database.
        try await withApp(configure: configure) { app in
            authenticate(UUID(), in: app)
            try await app.testing().test(.GET, "/api/v1/users") { response async in
                #expect(response.status == .internalServerError)
                #expect(response.body.string.contains("Unable to process user data"))
                #expect(!response.body.string.contains("SELECT"))
                #expect(!response.body.string.contains("no such table"))
                #expect(!response.body.string.contains("sqlite"))
            }
        }
    }

    @Test func migrationIsIdempotentAndReversibleOnIsolatedDatabase() async throws {
        try await withUsers { app, service async throws in
            let user = try await createMember(service)
            try await app.autoMigrate()
            #expect(try await UserModel.find(user.id, on: app.db) != nil)
            // Explicit rollback is confined to this test's isolated database.
            try await app.autoRevert()
            try await app.autoMigrate()
            #expect(try await UserModel.query(on: app.db).count() == 0)
        }
    }
}

private let testPassword = "correct horse battery staple"

private func withUsers(_ body: (Application, UserService) async throws -> Void) async throws {
    try await withApp(configure: { app in
        try await configure(app)
        // Real bcrypt, with reduced cost only in this test fixture.
        app.passwords.use(.bcrypt(cost: 4))
        try await app.autoMigrate()
    }) { app in
        let service = UserService(repository: FluentUserRepository(database: app.db),
                                  passwordHasher: VaporPasswordHasher(hasher: app.password.async))
        try await body(app, service)
    }
}

private func createMember(_ service: UserService) async throws -> User {
    try await service.create(name: "Alice Example", email: "alice@example.com", password: testPassword)
}

private func promoteForTest(_ id: UUID, on app: Application) async throws {
    try await UserModel.query(on: app.db).filter(\.$id == id).set(\.$role, to: "admin").update()
}

private func authenticate(_ id: UUID, in app: Application) {
    app.middleware.use(TestIdentityMiddleware(id: id))
}

// Test-only authentication fixture: never reads headers or exists in the production target.
private struct TestIdentityMiddleware: AsyncMiddleware {
    let id: UUID
    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        request.auth.login(UserIdentity(userID: id))
        return try await next.respond(to: request)
    }
}

private final class UserReference: Model, @unchecked Sendable {
    static let schema = "test_user_references"
    @ID(key: .id) var id: UUID?
    @Field(key: "user_id") var userID: UUID
    init() {}
    init(userID: UUID) { self.userID = userID }
}
