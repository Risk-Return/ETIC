import SwiftUI

/// 主界面底部标签栏：起卦 / 账号。
struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                CastingView()
            }
            .tabItem {
                Label(L10n.Nav.cast, systemImage: "sparkles")
            }
            .tag(0)

            NavigationStack {
                AccountView()
            }
            .tabItem {
                Label(L10n.Nav.account, systemImage: "person.crop.circle")
            }
            .tag(1)
        }
        .tint(InkTheme.cinnabar)
    }
}
