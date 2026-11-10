import Fluent

struct DatabaseReadinessCheck: ReadinessChecking {
  let database: any Database

  func check() async throws {
    // Acquire an actual pooled connection; driver connection initialization enables foreign keys.
    try await database.withConnection { connection in
      connection.eventLoop.makeSucceededVoidFuture()
    }.get()
  }
}
