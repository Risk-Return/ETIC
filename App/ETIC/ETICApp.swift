import SwiftUI

@main
struct ETICApp: App {
    @StateObject private var settings = RitualSettings()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                CastingView()
            }
            .tint(InkTheme.cinnabar)
            .environmentObject(settings)
        }
    }
}
