import Testing
@testable import App

@Suite("User input rules")
struct UserInputRulesTests {
    @Test(arguments: ["bad", "a@@example.com", ".a@example.com", "a..b@example.com", "a@localhost", "a@-bad.com", "a@example.com\nINJECT", "a b@example.com"])
    func rejectsInvalidEmail(email: String) {
        #expect(throws: UserError.self) { try UserInputRules.email(email) }
    }

    @Test(arguments: ["", "short", String(repeating: "x", count: 73), String(repeating: "🔐", count: 19), "valid-long-password\0"])
    func rejectsUnsafePasswordLengths(password: String) {
        #expect(throws: UserError.self) { try UserInputRules.password(password) }
    }

    @Test func acceptsBcryptByteBoundaryWithoutTrimmingPassword() throws {
        try UserInputRules.password(String(repeating: "x", count: 72))
        try UserInputRules.password(String(repeating: "🔐", count: 18))
        #expect(try UserInputRules.name(" João da Silva ") == "João da Silva")
        #expect(try UserInputRules.email(" ALICE+TAG@EXAMPLE.COM ") == "alice+tag@example.com")
    }

    @Test(arguments: ["", "A", String(repeating: "x", count: 101), "Alice\nExample"])
    func rejectsInvalidNames(name: String) {
        #expect(throws: UserError.self) { try UserInputRules.name(name) }
    }
}
