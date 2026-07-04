import Foundation

struct LocalizationStore {
    private static let store: [String: [String: String]] = {
        guard let url = Bundle.main.url(forResource: "Localizable", withExtension: "xcstrings"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONDecoder().decode(XCStringsRoot.self, from: data) else {
            return [:]
        }
        var result: [String: [String: String]] = [:]
        for (key, entry) in json.strings {
            var perLocale: [String: String] = [:]
            for (locale, loc) in entry.localizations {
                perLocale[locale] = loc.stringUnit.value
            }
            result[key] = perLocale
        }
        return result
    }()

    private static var currentLanguage: String {
        UserDefaults.standard.string(forKey: "app.language") ?? "en"
    }

    static func string(_ key: String) -> String {
        let lang = currentLanguage
        if let localized = store[key]?[lang], !localized.isEmpty {
            return localized
        }
        return store[key]?["en"] ?? key
    }
}

// MARK: - JSON models for xcstrings structure

private struct XCStringsRoot: Decodable {
    let strings: [String: XCStringsEntry]
}

private struct XCStringsEntry: Decodable {
    let localizations: [String: XCStringsLocalization]
}

private struct XCStringsLocalization: Decodable {
    let stringUnit: XCStringsUnit
}

private struct XCStringsUnit: Decodable {
    let value: String
}
