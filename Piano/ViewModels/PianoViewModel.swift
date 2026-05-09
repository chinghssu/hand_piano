import Foundation
import SwiftUI

final class PianoViewModel: ObservableObject {

    @Published var pads: [Pad] = Pad.cMajorDefault

    private let audio: PianoAudioEngine
    private var fingerChannelMap: [Int: UInt8] = [:]
    private var availableChannels: Set<UInt8> = [0, 1, 2, 3, 4]
    private var isSustainActive = false
    private var sustainedNotes: [UInt8: UInt8] = [:]  // note → channel

    init() {
        let hasSF2 = Bundle.main.url(forResource: "GeneralUser_GS", withExtension: "sf2") != nil
        if hasSF2 {
            let engine = SamplerAudioEngine()
            audio = engine
            try? engine.start()
        } else {
            let engine = SineAudioEngine()
            audio = engine
            try? engine.start()
        }
        VelocityDetector.shared.start()
    }

    // MARK: - Touch events

    func touchBegan(on pad: Pad, touchId: Int, majorRadius: CGFloat) {
        let ch = assignChannel(touchId)
        sustainedNotes.removeValue(forKey: pad.midiNote)
        let velocity = computeVelocity(majorRadius: majorRadius)
        audio.noteOn(note: pad.midiNote, velocity: velocity, channel: ch)
        let intensity = Float(Double(velocity - 30) / 97.0)
        HapticEngine.shared.tap(intensity: max(0.2, intensity))
    }

    /// 合成 A (加速度峰值) + B (觸碰半徑) → MIDI velocity 30...127
    /// 加速度為主 (0.7)，半徑為輔 (0.3)；不做情境偵測或校準。
    private func computeVelocity(majorRadius: CGFloat) -> UInt8 {
        let accelNorm = VelocityDetector.shared.currentPeak()  // 0...1
        // 經驗值：手指肉墊 majorRadius 約 8...28 點
        let radiusNorm = max(0.0, min(1.0, (Double(majorRadius) - 8.0) / 20.0))
        let combined = 0.7 * accelNorm + 0.3 * radiusNorm
        let mapped = 30.0 + combined * 97.0
        return UInt8(max(30.0, min(127.0, mapped)))
    }

    func touchEnded(on pad: Pad, touchId: Int) {
        let ch = channel(for: touchId)
        if isSustainActive {
            sustainedNotes[pad.midiNote] = ch
        } else {
            audio.noteOff(note: pad.midiNote, channel: ch)
        }
        releaseChannel(touchId)
    }

    func updatePitchBend(semitones: Double, touchId: Int) {
        let clamped = max(-2.0, min(2.0, semitones))
        let midiValue = UInt16(8192.0 + clamped / 2.0 * 8191.0)
        audio.pitchBend(value: midiValue, channel: channel(for: touchId))
    }

    // MARK: - Sustain

    func setSustain(_ active: Bool) {
        isSustainActive = active
        if !active {
            for (note, ch) in sustainedNotes {
                audio.noteOff(note: note, channel: ch)
            }
            sustainedNotes.removeAll()
        }
    }

    // MARK: - Channel pool

    private func assignChannel(_ touchId: Int) -> UInt8 {
        if let ch = fingerChannelMap[touchId] { return ch }
        let ch = availableChannels.popFirst() ?? 0
        fingerChannelMap[touchId] = ch
        return ch
    }

    private func channel(for touchId: Int) -> UInt8 {
        fingerChannelMap[touchId] ?? 0
    }

    private func releaseChannel(_ touchId: Int) {
        if let ch = fingerChannelMap.removeValue(forKey: touchId) {
            availableChannels.insert(ch)
        }
    }
}
