import Foundation

extension Date {
    /// "3h ago", localised to the language chosen **in the app**, not the device.
    ///
    /// A plain static `RelativeDateTimeFormatter` keeps whatever locale it was built
    /// with, so with the app set to Vietnamese on an English phone every timestamp in
    /// the feed stayed English. Reading `LanguagePreference.shared` also means the
    /// SwiftUI views that render these strings re-evaluate when the setting changes.
    @MainActor
    var relativeDescription: String {
        RelativeFormatterCache.formatter(for: LanguagePreference.shared.locale)
            .localizedString(for: self, relativeTo: Date())
    }
}

@MainActor
private enum RelativeFormatterCache {
    private static var cached: (identifier: String, formatter: RelativeDateTimeFormatter)?

    static func formatter(for locale: Locale) -> RelativeDateTimeFormatter {
        if let cached, cached.identifier == locale.identifier {
            return cached.formatter
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.locale = locale
        cached = (locale.identifier, formatter)
        return formatter
    }
}
