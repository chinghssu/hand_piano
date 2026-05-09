import Foundation
import CoreHaptics
import UIKit

/// Core Haptics 包裝；不可用時 fallback 到 UIImpactFeedbackGenerator。
final class HapticEngine {

    static let shared = HapticEngine()

    private var engine: CHHapticEngine?
    private let supportsHaptics: Bool
    private let fallback = UIImpactFeedbackGenerator(style: .medium)

    private init() {
        supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
        if supportsHaptics {
            do {
                let e = try CHHapticEngine()
                e.isAutoShutdownEnabled = true
                e.resetHandler = { [weak self] in
                    try? self?.engine?.start()
                }
                try e.start()
                engine = e
            } catch {
                engine = nil
            }
        }
        fallback.prepare()
    }

    /// 觸發 transient tap，intensity/sharpness 範圍 0...1
    func tap(intensity: Float, sharpness: Float = 0.7) {
        let i = max(0, min(1, intensity))
        let s = max(0, min(1, sharpness))

        if supportsHaptics, let engine {
            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: i),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: s)
                ],
                relativeTime: 0
            )
            do {
                let pattern = try CHHapticPattern(events: [event], parameters: [])
                let player = try engine.makePlayer(with: pattern)
                try player.start(atTime: 0)
            } catch {
                fallback.impactOccurred(intensity: CGFloat(i))
            }
        } else {
            fallback.impactOccurred(intensity: CGFloat(i))
        }
    }
}
