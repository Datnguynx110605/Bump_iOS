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

/// Captions and comment bodies share one server-side ceiling (`ChangeCaptionValidator`
/// and `ChangeContentValidator` both cap at 2000). Both may be empty — clearing a caption
/// is a legitimate edit — so the only rule is the length.
enum FreeTextRule {
    static let maxLength = 2000
    /// How close to the ceiling the counter appears. Showing "1974 left" from the first
    /// keystroke is noise; showing nothing until a 400 comes back is worse.
    static let counterThreshold = 200

    static func isValid(_ text: String) -> Bool {
        text.count <= maxLength
    }

    /// Characters left, or nil while the limit is far enough away not to matter.
    static func remaining(_ text: String) -> Int? {
        let left = maxLength - text.count
        return left <= counterThreshold ? left : nil
    }
}
