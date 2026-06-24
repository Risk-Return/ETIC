import SwiftUI

/// 动画与体感设置。
struct RitualSettingsView: View {
    @EnvironmentObject private var settings: RitualSettings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    var body: some View {
        NavigationStack {
            Form {
                Section("动画") {
                    Toggle("跳过占卜动画", isOn: $settings.skipAnimation)
                    if systemReduceMotion {
                        Text("系统已开启「减弱动态」，动画将自动降级。")
                            .font(.footnote)
                            .foregroundStyle(InkTheme.inkSoft)
                    }
                }
                Section("摇卦") {
                    Toggle("摇一摇触发摇卦", isOn: $settings.shakeToToss)
                    Toggle("触觉反馈", isOn: $settings.haptics)
                }
                Section {
                    Text("动画仅为演出，不影响起卦结果——盘面始终由本地引擎确定性算出。")
                        .font(.footnote)
                        .foregroundStyle(InkTheme.inkSoft)
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}
