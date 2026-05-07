import AVFoundation
import os

// Phase 1 audio engine: sine-wave synthesiser, no external soundfont files needed.
// Replace with SamplerAudioEngine once Salamander SF2 is bundled (Phase 1.1).
final class SineAudioEngine: PianoAudioEngine {

    private let engine = AVAudioEngine()
    private let notesLock = OSAllocatedUnfairLock(initialState: [UInt8: SineOscillator]())
    private var sourceNode: AVAudioSourceNode?
    private let sampleRate: Double = 44100

    func start() throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!

        let node = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, audioBufferList in
            guard let self else { return noErr }
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let count = Int(frameCount)

            for buffer in ablPointer {
                let ptr = buffer.mData!.assumingMemoryBound(to: Float.self)
                for frame in 0..<count {
                    // Accumulate inside the lock so no mutable var is captured in the closure
                    let sample: Float = self.notesLock.withLock { notes in
                        notes.values.reduce(into: Float(0)) { acc, osc in
                            acc += osc.nextSample()
                        }
                    }
                    // Soft-clip prevents clipping when multiple notes play together
                    ptr[frame] = tanh(sample * 0.4)
                }
            }
            return noErr
        }

        sourceNode = node
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 1.0

#if os(iOS)
        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try AVAudioSession.sharedInstance().setActive(true)
#endif
        try engine.start()
    }

    func stop() {
        engine.stop()
    }

    func noteOn(note: UInt8, velocity: UInt8, channel: UInt8) {
        let freq = midiNoteToHz(note)
        let amp = Float(velocity) / 127.0
        notesLock.withLock { notes in
            notes[note] = SineOscillator(frequency: freq, amplitude: amp, sampleRate: sampleRate)
        }
    }

    func noteOff(note: UInt8, channel: UInt8) {
        _ = notesLock.withLock { notes in
            notes.removeValue(forKey: note)
        }
    }

    // Pitch bend value 0–16383, center = 8192; maps ±full range → ±2 semitones
    func pitchBend(value: UInt16, channel: UInt8) {
        let normalised = (Double(value) - 8192.0) / 8191.0   // −1 to +1
        let semitones = normalised * 2.0
        notesLock.withLock { notes in
            for key in notes.keys {
                let bentFreq = midiNoteToHz(key) * pow(2.0, semitones / 12.0)
                notes[key]?.setFrequency(bentFreq, sampleRate: sampleRate)
            }
        }
    }

    private func midiNoteToHz(_ note: UInt8) -> Double {
        440.0 * pow(2.0, (Double(note) - 69.0) / 12.0)
    }
}

// MARK: - Oscillator

// Class (not struct) so the audio render block can mutate phase without copies.
final class SineOscillator {
    private var phase: Double = 0
    private var phaseIncrement: Double
    let amplitude: Float

    init(frequency: Double, amplitude: Float, sampleRate: Double) {
        self.phaseIncrement = 2.0 * .pi * frequency / sampleRate
        self.amplitude = amplitude
    }

    func setFrequency(_ freq: Double, sampleRate: Double) {
        phaseIncrement = 2.0 * .pi * freq / sampleRate
    }

    // Must only be called from audio render thread while notesLock is held.
    func nextSample() -> Float {
        let s = Float(sin(phase)) * amplitude
        phase += phaseIncrement
        if phase >= 2.0 * .pi { phase -= 2.0 * .pi }
        return s
    }
}
