import Foundation
import SwiftUI

enum VelocityMode: String, CaseIterable, Identifiable {
    case auto, accelerometer, radius, fixed
    var id: String { rawValue }
    var label: String {
        switch self {
        case .auto: return "自動 (加速度+半徑)"
        case .accelerometer: return "加速度計"
        case .radius: return "觸碰半徑"
        case .fixed: return "固定 100"
        }
    }
}

enum VelocityCurve: String, CaseIterable, Identifiable {
    case linear, log, exp
    var id: String { rawValue }
    var label: String {
        switch self {
        case .linear: return "線性"
        case .log: return "柔 (log)"
        case .exp: return "銳 (exp)"
        }
    }

    /// input 0...1 → output 0...1
    func apply(_ x: Double) -> Double {
        let v = max(0, min(1, x))
        switch self {
        case .linear: return v
        case .log: return v == 0 ? 0 : log10(1 + 9 * v)         // 平滑提亮輕觸
        case .exp: return v * v                                  // 強調差異
        }
    }
}

/// 全域設定。SwiftUI View 用 @AppStorage 直接綁定，
/// 非 View 端 (ViewModel) 透過 shared 實例讀。
final class SettingsStore: ObservableObject {

    static let shared = SettingsStore()

    @AppStorage("padScale") var padScale: Double = 1.0          // 0.6 ... 1.6
    @AppStorage("hapticIntensity") var hapticIntensity: Double = 0.7
    @AppStorage("bendSensitivity") var bendSensitivity: Double = 80.0   // 像素 / 半音
    @AppStorage("bendMaxSemitones") var bendMaxSemitones: Double = 2.0
    @AppStorage("velocityModeRaw") var velocityModeRaw: String = VelocityMode.auto.rawValue
    @AppStorage("velocityCurveRaw") var velocityCurveRaw: String = VelocityCurve.linear.rawValue

    var velocityMode: VelocityMode {
        VelocityMode(rawValue: velocityModeRaw) ?? .auto
    }
    var velocityCurve: VelocityCurve {
        VelocityCurve(rawValue: velocityCurveRaw) ?? .linear
    }

    private init() {}
}
