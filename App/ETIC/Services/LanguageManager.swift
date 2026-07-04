import SwiftUI

enum AppLanguage: String, CaseIterable {
    case en
    case zhHans = "zh-Hans"

    var displayName: String {
        switch self {
        case .en: return "English"
        case .zhHans: return "中文"
        }
    }

    var locale: Locale { Locale(identifier: rawValue) }
}

final class LanguageManager: ObservableObject {
    @AppStorage("app.language") var languageCode: String = AppLanguage.en.rawValue

    var selectedLanguage: AppLanguage {
        get { AppLanguage(rawValue: languageCode) ?? .en }
        set { languageCode = newValue.rawValue }
    }

    var locale: Locale { selectedLanguage.locale }

    var languageBinding: Binding<AppLanguage> {
        Binding<AppLanguage>(
            get: { [weak self] in self?.selectedLanguage ?? .en },
            set: { [weak self] in self?.selectedLanguage = $0 }
        )
    }
}
