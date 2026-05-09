import AVFoundation

final class SamplerAudioEngine: PianoAudioEngine {

    private let engine = AVAudioEngine()
    private let sampler = AVAudioUnitSampler()

    func start() throws {
        engine.attach(sampler)
        engine.connect(sampler, to: engine.mainMixerNode, format: nil)

#if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setPreferredIOBufferDuration(0.005)
        try session.setActive(true)
#endif
        try engine.start()

        guard let url = Bundle.main.url(forResource: "GeneralUser_GS", withExtension: "sf2") else {
            throw SamplerError.soundFontNotFound
        }
        // program 0 = Acoustic Grand Piano; bankMSB 0x79 = default melodic bank
        try sampler.loadSoundBankInstrument(at: url, program: 0, bankMSB: 0x79, bankLSB: 0)
    }

    func stop() {
        engine.stop()
    }

    func noteOn(note: UInt8, velocity: UInt8, channel: UInt8) {
        sampler.startNote(note, withVelocity: velocity, onChannel: channel)
    }

    func noteOff(note: UInt8, channel: UInt8) {
        sampler.stopNote(note, onChannel: channel)
    }

    // value 0–16383, center = 8192
    func pitchBend(value: UInt16, channel: UInt8) {
        let lsb = UInt8(value & 0x7F)
        let msb = UInt8((value >> 7) & 0x7F)
        sampler.sendMIDIEvent(0xE0 | (channel & 0x0F), data1: lsb, data2: msb)
    }
}

enum SamplerError: Error {
    case soundFontNotFound
}
