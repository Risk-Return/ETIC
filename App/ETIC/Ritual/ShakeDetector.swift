import Foundation
import CoreMotion

/// 摇一摇检测：CoreMotion 加速度阈值触发，带去抖冷却。
/// 仅作动画"触发器"，不影响起卦结果（结果已由引擎确定）。
final class ShakeDetector: ObservableObject {
    private let motion = CMMotionManager()
    private let queue = OperationQueue()
    private var lastTrigger = Date.distantPast

    /// 触发阈值（合加速度，单位 g）与冷却（秒）。
    var threshold: Double = 2.2
    var cooldown: TimeInterval = 0.6

    /// 检测到摇动时回调（主线程）。
    var onShake: (() -> Void)?

    var isAvailable: Bool { motion.isAccelerometerAvailable }

    func start() {
        guard motion.isAccelerometerAvailable, !motion.isAccelerometerActive else { return }
        motion.accelerometerUpdateInterval = 1.0 / 50.0
        motion.startAccelerometerUpdates(to: queue) { [weak self] data, _ in
            guard let self, let a = data?.acceleration else { return }
            let magnitude = sqrt(a.x * a.x + a.y * a.y + a.z * a.z)
            guard magnitude > self.threshold else { return }
            let now = Date()
            guard now.timeIntervalSince(self.lastTrigger) > self.cooldown else { return }
            self.lastTrigger = now
            DispatchQueue.main.async { self.onShake?() }
        }
    }

    func stop() {
        if motion.isAccelerometerActive { motion.stopAccelerometerUpdates() }
    }
}
