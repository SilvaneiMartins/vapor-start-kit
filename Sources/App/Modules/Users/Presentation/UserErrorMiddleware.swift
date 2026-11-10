import Vapor

struct UserErrorMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        do {
            return try await next.respond(to: request)
        } catch let error as UserError {
            switch error {
            case .invalidInput(let message): throw Abort(.badRequest, reason: message)
            case .emailAlreadyExists: throw Abort(.conflict, reason: "Email is already registered")
            case .notFound: throw Abort(.notFound, reason: "User not found")
            case .unauthenticated: throw Abort(.unauthorized, reason: "Authentication required")
            case .forbidden: throw Abort(.forbidden, reason: "Access denied")
            case .storageFailure: throw Abort(.internalServerError, reason: "Unable to process user data")
            }
        } catch let error as any AbortError {
            throw error
        } catch {
            // Never expose persistence errors, even in development.
            throw Abort(.internalServerError, reason: "Unable to process user data")
        }
    }
}
