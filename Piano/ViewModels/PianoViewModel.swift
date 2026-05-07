import Foundation
import SwiftUI

@Observable
final class PianoViewModel {

    var pads: [Pad] = Pad.cMajorDefault

    private let audio: PianoAudioEngine
    // Maps UITouch.hash → MIDI channel (0–4, one per finger)
    private var fingerChannelMap: [Int: UInt8] = [:]
    private var availableChannels: Set<UInt8> = [0, 1, 2, 3, 4]

    init() {
        let engine = SineAudioEngine()
        audio = engine
        try? engine.start()
    }

    // MARK: - Touch events

    func touchBegan(on pad: Pad, velocity: UInt8, touchId: Int) {
        let ch = assignChannel(touchId)
        audio.noteOn(note: pad.midiNote, velocity: velocity, channel: ch)
    }

    func touchEnded(on pad: Pad, touchId: Int) {
        let ch = channel(for: touchId)
        audio.noteOff(note: pad.midiNote, channel: ch)
        releaseChannel(touchId)
    }

    // semitones: negative = lower pitch, positive = higher; range clamped to ±2
    func updatePitchBend(semitones: Double, touchId: Int) {
        let clamped = max(-2.0, min(2.0, semitones))
        let midiValue = UInt16(8192.0 + clamped / 2.0 * 8191.0)
        audio.pitchBend(value: midiValue, channel: channel(for: touchId))
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
