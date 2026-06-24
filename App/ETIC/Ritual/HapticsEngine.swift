import Foundation
import CoreHaptics
import UIKit

/// 触觉反馈：优先 CoreHaptics（可塑「铜钱叮当」），不可用时降级为 `UIImpactFeedbackGenerator`。
/// 动画演出层，不参与术数计算。
final class HapticsEngine {
    private var engine: CHHapticEngine?
    private let supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics

    func prepare() {
        guard supportsHaptics, engine == nil else { return }
        engine = try? CHHapticEngine()
        try? engine?.start()
    }

    func stop() {
        engine?.stop(completionHandler: nil)
        engine = nil
    }

    /// 铜钱落地的清脆叮当：两个紧邻的瞬态。
    func coinDrop(intensity: Float = 0.8) {
        guard supportsHaptics, let engine else {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            return
        }
        let events = [
            transient(at: 0, intensity: intensity, sharpness: 0.9),
            transient(at: 0.08, intensity: intensity * 0.7, sharpness: 0.7)
        ]
        play(events, on: engine)
    }

    /// 成卦/动爻：一次轻柔脉冲。
    func tap(intensity: Float = 0.5) {
        guard supportsHaptics, let engine else {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            return
        }
        play([transient(at: 0, intensity: intensity, sharpness: 0.5)], on: engine)
    }

    private func transient(at time: TimeInterval, intensity: Float, sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
            ],
            relativeTime: time
        )
    }

    private func play(_ events: [CHHapticEvent], on engine: CHHapticEngine) {
        guard let pattern = try? CHHapticPattern(events: events, parameters: []),
              let player = try? engine.makePlayer(with: pattern) else { return }
        try? player.start(atTime: 0)
    }
}
