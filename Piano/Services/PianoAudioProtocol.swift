import Foundation

protocol PianoAudioEngine: AnyObject {
    func start() throws
    func stop()
    func noteOn(note: UInt8, velocity: UInt8, channel: UInt8)
    func noteOff(note: UInt8, channel: UInt8)
    // value 0–16383, center = 8192
    func pitchBend(value: UInt16, channel: UInt8)
}
