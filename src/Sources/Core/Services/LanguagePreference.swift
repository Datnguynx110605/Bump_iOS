import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english = "en"
    case vietnamese = "vi"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: "System"
        case .english: "English"
        case .vietnamese: "Tiếng Việt"
        }
    }

    fileprivate var locale: Locale? {
        switch self {
        case .system: nil
        case .english: Locale(identifier: "en")
        case .vietnamese: Locale(identifier: "vi")
        }
    }
}

@Observable
final class LanguagePreference {
    static let shared = LanguagePreference()

    private static let storageKey = "appLanguage"

    var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: Self.storageKey) }
    }

    var locale: Locale {
        language.locale ?? Locale.autoupdatingCurrent
    }

    private init() {
        let stored = UserDefaults.standard.string(forKey: Self.storageKey) ?? AppLanguage.system.rawValue
        language = AppLanguage(rawValue: stored) ?? .system
    }
}
