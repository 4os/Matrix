import Foundation

/// In-app language choice (TR / EN toggle in the panel footer). Defaults to the system language.
enum AppLanguage: String, CaseIterable {
    case tr, en

    static let storageKey = "language"

    static var systemDefault: AppLanguage {
        Bundle.main.preferredLocalizations.first == "tr" ? .tr : .en
    }

    static var current: AppLanguage {
        UserDefaults.standard.string(forKey: storageKey).flatMap(AppLanguage.init) ?? systemDefault
    }

    var locale: Locale { Locale(identifier: rawValue) }

    /// Resolves a key from the string catalog in this language, regardless of the system language.
    func string(_ key: String.LocalizationValue) -> String {
        switch self {
        case .tr: String(localized: key, bundle: Self.turkish)
        // English is the catalog's source language: a table that doesn't exist yields the source text.
        case .en: String(localized: key, table: "SourceLanguage")
        }
    }

    private static let turkish = Bundle.main.path(forResource: "tr", ofType: "lproj").flatMap(Bundle.init(path:)) ?? .main
}

/// Localized string in the language chosen in the app.
func localized(_ key: String.LocalizationValue) -> String {
    AppLanguage.current.string(key)
}
