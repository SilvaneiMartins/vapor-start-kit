import Foundation
import Fluent

struct FluentUserRepository: UserRepository {
    let database: any Database

    func find(id: UUID) async throws -> User? {
        try await UserModel.find(id, on: database)?.toDomain()
    }

    func find(email: String) async throws -> User? {
        try await UserModel.query(on: database).filter(\.$email == email).first()?.toDomain()
    }

    func create(_ user: User) async throws -> User {
        // Normalize at the persistence boundary as well as the service boundary.
        let model = UserModel(user)
        model.email = try UserInputRules.email(user.email)
        do {
            try await model.create(on: database)
        } catch {
            try await translateWriteError(error, email: model.email)
        }
        return try model.toDomain()
    }

    func list(_ pagination: UserPagination) async throws -> UserPage {
        try await database.transaction { database in
            let total = try await UserModel.query(on: database).count()
            let models = try await UserModel.query(on: database)
                .sort(\.$createdAt).sort(\.$id)
                .range(pagination.offset..<(pagination.offset + pagination.perPage)).all()
            return try UserPage(items: models.map { try $0.toDomain() }, total: total, pagination: pagination)
        }
    }

    func updateProfile(id: UUID, name: String?, email: String?, at date: Date) async throws -> User {
        let normalizedEmail = try email.map(UserInputRules.email)
        let query = UserModel.query(on: database).filter(\.$id == id).filter(\.$isActive == true)
            .set(\.$updatedAt, to: date)
        if let name { query.set(\.$name, to: name) }
        if let normalizedEmail { query.set(\.$email, to: normalizedEmail) }
        do {
            try await query.update()
        } catch {
            try await translateWriteError(error, email: normalizedEmail)
        }
        guard let user = try await find(id: id) else { throw UserError.notFound }
        guard user.isActive else { throw UserError.forbidden }
        return user
    }

    func deactivate(id: UUID, at date: Date) async throws {
        // Update only these fields: stale profile data must never reactivate an account.
        try await UserModel.query(on: database).filter(\.$id == id)
            .set(\.$isActive, to: false).set(\.$updatedAt, to: date).update()
    }

    private func translateWriteError(_ error: any Error, email: String?) async throws -> Never {
        if let databaseError = error as? any DatabaseError, databaseError.isConstraintFailure,
           let email, try await find(email: email) != nil {
            throw UserError.emailAlreadyExists
        }
        // Do not propagate SQL or bound values through the presentation layer.
        throw UserError.storageFailure
    }
}
