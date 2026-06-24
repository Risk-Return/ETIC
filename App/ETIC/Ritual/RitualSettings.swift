import SwiftUI

/// 动画偏好（持久化）。与系统 Reduce Motion 合并决定是否降级。
final class RitualSettings: ObservableObject {
    /// 用户「跳过动画」开关：开启后起卦直达盘面。
    @AppStorage("ritual.skipAnimation") var skipAnimation: Bool = false
    /// 是否启用摇一摇（CoreMotion）触发摇卦。
    @AppStorage("ritual.shakeToToss") var shakeToToss: Bool = true
    /// 是否启用触觉反馈。
    @AppStorage("ritual.haptics") var haptics: Bool = true
}
