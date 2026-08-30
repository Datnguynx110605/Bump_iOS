import Foundation

enum AccountNameRule {
    static func isValid(_ name: String) -> Bool {
        !name.isEmpty
            && name.count <= 200
            && name.allSatisfy { $0.isLowercase || $0.isNumber }
    }

    static func sanitize(_ input: String) -> String {
        String(input.lowercased().filter { $0.isLowercase || $0.isNumber })
    }
}

enum PasswordRule {
    static let range = 10...40

    static func isValid(_ password: String) -> Bool {
        range.contains(password.count)
    }
}

enum EmailRule {
    static func isValid(_ email: String) -> Bool {
        email.contains("@") && email.count <= 200 && !email.hasPrefix("@") && !email.hasSuffix("@")
    }
}
