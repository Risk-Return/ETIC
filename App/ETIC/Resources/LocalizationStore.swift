import Foundation

struct LocalizationStore {
    private static let store: [String: [String: String]] = {
        guard let url = Bundle.main.url(forResource: "translations", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let result = try? JSONDecoder().decode([String: [String: String]].self, from: data) else {
            return [:]
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
