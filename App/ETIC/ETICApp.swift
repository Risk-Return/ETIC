import SwiftUI
import SwiftData

@main
struct ETICApp: App {
    @StateObject private var settings = RitualSettings()
    @StateObject private var language = LanguageManager()
    @StateObject private var auth = AuthService.shared
    @AppStorage("app.language") private var appLanguage = AppLanguage.en.rawValue

    var body: some Scene {
        WindowGroup {
            if auth.isAuthenticated {
                MainTabView()
                    .environmentObject(settings)
                    .environmentObject(language)
                    .environment(\.locale, language.locale)
            } else {
                LoginView()
                    .environmentObject(settings)
                    .environmentObject(language)
                    .environment(\.locale, language.locale)
            }
        }
        .modelContainer(for: DivinationRecord.self)
    }
}
