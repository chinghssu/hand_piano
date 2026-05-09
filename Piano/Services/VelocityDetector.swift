import Foundation
import CoreMotion

/// 以 100Hz 取樣 user acceleration，維持最近 50ms 視窗的峰值。
/// 觸碰當下呼叫 `currentPeak()` 即可拿到敲擊力道指標 (0...1 normalized)。
final class VelocityDetector {

    static let shared = VelocityDetector()

    private let motion = CMMotionManager()
    private let queue = OperationQueue()

    private struct Sample { let time: TimeInterval; let magnitude: Double }
    private var window: [Sample] = []
    private let lock = NSLock()

    private let windowDuration: TimeInterval = 0.05
    /// 經驗值：手持輕敲約 0.3g，重敲 1.5g+。用 1.5 當分母把 0...1.5g 映射到 0...1。
    private let normalizer: Double = 1.5

    private init() {
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInteractive
    }

    func start() {
        guard motion.isDeviceMotionAvailable, !motion.isDeviceMotionActive else { return }
        motion.deviceMotionUpdateInterval = 1.0 / 100.0
        motion.startDeviceMotionUpdates(to: queue) { [weak self] data, _ in
            guard let self, let d = data else { return }
            let a = d.userAcceleration
            let mag = sqrt(a.x * a.x + a.y * a.y + a.z * a.z)
            self.append(magnitude: mag, time: d.timestamp)
        }
    }

    func stop() {
        motion.stopDeviceMotionUpdates()
    }

    /// 取最近 50ms 內的加速度峰值 (normalized to 0...1)
    func currentPeak() -> Double {
        let now = ProcessInfo.processInfo.systemUptime
        lock.lock(); defer { lock.unlock() }
        prune(now: now)
        let peak = window.map { $0.magnitude }.max() ?? 0
        return min(1.0, peak / normalizer)
    }

    private func append(magnitude: Double, time: TimeInterval) {
        lock.lock(); defer { lock.unlock() }
        window.append(Sample(time: time, magnitude: magnitude))
        prune(now: time)
    }

    private func prune(now: TimeInterval) {
        let cutoff = now - windowDuration
        while let first = window.first, first.time < cutoff {
            window.removeFirst()
        }
    }
}
