import SwiftUI

@main
struct ETICApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                CastingView()
            }
            .tint(InkTheme.cinnabar)
        }
    }
}
