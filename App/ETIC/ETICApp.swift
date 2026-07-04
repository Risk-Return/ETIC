import SwiftUI
import SwiftData

@main
struct ETICApp: App {
    @StateObject private var settings = RitualSettings()
    @StateObject private var language = LanguageManager()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                CastingView()
            }
            .tint(InkTheme.cinnabar)
            .environmentObject(settings)
            .environmentObject(language)
            .environment(\.locale, language.locale)
        }
        .modelContainer(for: DivinationRecord.self)
    }
}
