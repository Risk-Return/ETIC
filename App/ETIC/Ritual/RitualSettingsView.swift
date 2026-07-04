import SwiftUI

/// 动画与体感设置。
struct RitualSettingsView: View {
    @EnvironmentObject private var settings: RitualSettings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage("app.language") private var storedLanguage = AppLanguage.en.rawValue

    private var languageBinding: Binding<AppLanguage> {
        Binding<AppLanguage>(
            get: { AppLanguage(rawValue: storedLanguage) ?? .en },
            set: { storedLanguage = $0.rawValue }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.Settings.languageSection) {
                    Picker(L10n.Settings.languageLabel, selection: languageBinding) {
                        ForEach(AppLanguage.allCases, id: \.self) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                }
                Section(L10n.Settings.animationSection) {
                    Toggle(L10n.Settings.skipAnimation, isOn: $settings.skipAnimation)
                    if systemReduceMotion {
                        Text(L10n.Settings.reduceMotionNotice)
                            .font(.footnote)
                            .foregroundStyle(InkTheme.inkSoft)
                    }
                }
                Section(L10n.Settings.shakeSection) {
                    Toggle(L10n.Settings.shakeToToss, isOn: $settings.shakeToToss)
                    Toggle(L10n.Settings.haptics, isOn: $settings.haptics)
                }
                Section {
                    Text(L10n.Settings.note)
                        .font(.footnote)
                        .foregroundStyle(InkTheme.inkSoft)
                }
            }
            .navigationTitle(L10n.Nav.settings)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.Settings.done) { dismiss() }
                }
            }
        }
    }
}
