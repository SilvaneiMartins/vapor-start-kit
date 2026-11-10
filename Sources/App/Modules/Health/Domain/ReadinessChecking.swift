protocol ReadinessChecking: Sendable {
  func check() async throws
}
