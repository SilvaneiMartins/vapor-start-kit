import Vapor

struct VaporPasswordHasher: PasswordHashing {
    let hasher: AsyncPasswordHasher

    func hash(_ password: String) async throws -> String {
        try await hasher.hash(password)
    }
}
