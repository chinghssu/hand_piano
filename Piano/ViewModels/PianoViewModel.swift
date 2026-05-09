import Foundation
import SwiftUI
import Combine

final class PianoViewModel: ObservableObject {

    @Published var pads: [Pad] = []

    let presetStore: PresetStore
    private let settings = SettingsStore.shared
    private let audio: PianoAudioEngine
    private var fingerChannelMap: [Int: UInt8] = [:]
    private var availableChannels: Set<UInt8> = [0, 1, 2, 3, 4]
    private var isSustainActive = false
    private var sustainedNotes: [UInt8: UInt8] = [:]  // note → channel
    private var cancellables: Set<AnyCancellable> = []

    init(presetStore: PresetStore = PresetStore()) {
        self.presetStore = presetStore

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

        pads = presetStore.current.pads
        // 切換 preset 時：停掉所有發聲，重新載入 pads
        presetStore.$currentID
            .dropFirst()
            .sink { [weak self] _ in self?.handlePresetChange() }
            .store(in: &cancellables)
        // 編輯 preset (例如新增/刪除 pad) 時，把 pads 同步過來
        presetStore.$presets
            .dropFirst()
            .sink { [weak self] _ in
                guard let self else { return }
                self.pads = self.presetStore.current.pads
            }
            .store(in: &cancellables)
    }

    private func handlePresetChange() {
        // 停掉所有正在發聲的音
        for ch in 0..<5 {
            for note in 0..<128 {
                audio.noteOff(note: UInt8(note), channel: UInt8(ch))
            }
        }
        sustainedNotes.removeAll()
        fingerChannelMap.removeAll()
        availableChannels = [0, 1, 2, 3, 4]
        pads = presetStore.current.pads
    }

    /// 編輯模式下儲存目前 pads 進 preset
    func savePadsToPreset() {
        presetStore.updateCurrentPads(pads)
    }

    // MARK: - Touch events

    func touchBegan(on pad: Pad, touchId: Int, majorRadius: CGFloat) {
        let ch = assignChannel(touchId)
        sustainedNotes.removeValue(forKey: pad.midiNote)
        let velocity = computeVelocity(majorRadius: majorRadius)
        audio.noteOn(note: pad.midiNote, velocity: velocity, channel: ch)
        let intensity = Float(Double(velocity - 30) / 97.0) * Float(settings.hapticIntensity)
        HapticEngine.shared.tap(intensity: max(0.05, intensity))
    }

    /// 合成 A (加速度峰值) + B (觸碰半徑) → MIDI velocity 30...127
    /// 來源 / 曲線依 SettingsStore；不做情境偵測或校準。
    private func computeVelocity(majorRadius: CGFloat) -> UInt8 {
        let accelNorm = VelocityDetector.shared.currentPeak()
        let radiusNorm = max(0.0, min(1.0, (Double(majorRadius) - 8.0) / 20.0))

        let raw: Double
        switch settings.velocityMode {
        case .auto:          raw = 0.7 * accelNorm + 0.3 * radiusNorm
        case .accelerometer: raw = accelNorm
        case .radius:        raw = radiusNorm
        case .fixed:         raw = (100.0 - 30.0) / 97.0
        }
        let shaped = settings.velocityCurve.apply(raw)
        let mapped = 30.0 + shaped * 97.0
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
        let maxBend = settings.bendMaxSemitones
        let clamped = max(-maxBend, min(maxBend, semitones))
        let normalized = clamped / maxBend  // -1...1
        let midiValue = UInt16(8192.0 + normalized * 8191.0)
        audio.pitchBend(value: midiValue, channel: channel(for: touchId))
    }

    var bendSensitivity: Double { settings.bendSensitivity }
    var bendMaxSemitones: Double { settings.bendMaxSemitones }

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
