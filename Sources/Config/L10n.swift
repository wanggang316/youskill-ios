import Foundation

enum L10n {
    static func string(_ key: String, appLanguage: AppLanguage = .current()) -> String {
        bundle(for: appLanguage).localizedString(forKey: key, value: nil, table: nil)
    }

    static func format(_ key: String, _ arguments: CVarArg..., appLanguage: AppLanguage = .current()) -> String {
        String(
            format: string(key, appLanguage: appLanguage),
            locale: appLanguage.locale,
            arguments: arguments
        )
    }

    private static func bundle(for appLanguage: AppLanguage) -> Bundle {
        let availableLocalizations = resourceBundle.localizations.filter { $0 != "Base" }
        let preferred = appLanguage.preferredLocalizationIdentifiers
        let resolved = Bundle.preferredLocalizations(
            from: availableLocalizations,
            forPreferences: preferred
        )

        for localization in resolved + ["en"] {
            guard let path = resourceBundle.path(forResource: localization, ofType: "lproj"),
                  let bundle = Bundle(path: path) else {
                continue
            }
            return bundle
        }

        return resourceBundle
    }

    private static var resourceBundle: Bundle {
        #if SWIFT_PACKAGE
        Bundle.module
        #else
        Bundle.main
        #endif
    }
}
