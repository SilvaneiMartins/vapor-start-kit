import Foundation

enum UserInputRules {
    static func name(_ input: String) throws -> String {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (2...100).contains(value.count),
              value.rangeOfCharacter(from: .controlCharacters) == nil else {
            throw UserError.invalidInput("Name must contain 2...100 characters without control characters")
        }
        return value
    }

    static func email(_ input: String) throws -> String {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let parts = value.split(separator: "@", omittingEmptySubsequences: false)
        let pattern = #"^[a-z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-z0-9](?:[a-z0-9-]*[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]*[a-z0-9])?)+$"#
        guard value.utf8.count <= 254, parts.count == 2,
              (1...64).contains(parts[0].utf8.count),
              !parts[0].hasPrefix("."), !parts[0].hasSuffix("."), !parts[0].contains(".."),
              parts[1].split(separator: ".").allSatisfy({ $0.count <= 63 }),
              value.range(of: pattern, options: .regularExpression) != nil else {
            throw UserError.invalidInput("Email must be a valid ASCII email address")
        }
        return value
    }

    static func password(_ input: String) throws {
        // Bcrypt truncates passwords beyond 72 bytes; reject rather than silently truncate.
        guard input.count >= 12, input.utf8.count <= 72, !input.utf8.contains(0) else {
            throw UserError.invalidInput("Password must contain at least 12 characters and at most 72 UTF-8 bytes, without NUL")
        }
    }
}
