import Foundation

struct Preset: Identifiable, Codable {
    let id: UUID
    var name: String
    var pads: [Pad]
    var isBuiltIn: Bool

    init(id: UUID = UUID(), name: String, pads: [Pad], isBuiltIn: Bool = false) {
        self.id = id
        self.name = name
        self.pads = pads
        self.isBuiltIn = isBuiltIn
    }
}

extension Preset {
    static let cMajor = Preset(
        name: "C 大調",
        pads: Pad.cMajorDefault,
        isBuiltIn: true
    )

    static let aMinor = Preset(
        name: "A 小調",
        pads: [
            Pad(midiNote: 57, label: "La"),   // A3
            Pad(midiNote: 59, label: "Si"),   // B3
            Pad(midiNote: 60, label: "Do"),   // C4
            Pad(midiNote: 62, label: "Re"),   // D4
            Pad(midiNote: 64, label: "Mi"),   // E4
            Pad(midiNote: 65, label: "Fa"),   // F4
            Pad(midiNote: 67, label: "Sol"),  // G4
            Pad(midiNote: 69, label: "La↑"),  // A4
            Pad(midiNote: 71, label: "Si↑"),  // B4
            Pad(midiNote: 72, label: "Do↑"),  // C5
        ],
        isBuiltIn: true
    )

    /// 五聲音階 (C D E G A) 跨兩個八度
    static let pentatonic = Preset(
        name: "五聲音階",
        pads: [
            Pad(midiNote: 60, label: "Do"),   // C4
            Pad(midiNote: 62, label: "Re"),   // D4
            Pad(midiNote: 64, label: "Mi"),   // E4
            Pad(midiNote: 67, label: "Sol"),  // G4
            Pad(midiNote: 69, label: "La"),   // A4
            Pad(midiNote: 72, label: "Do↑"),  // C5
            Pad(midiNote: 74, label: "Re↑"),  // D5
            Pad(midiNote: 76, label: "Mi↑"),  // E5
            Pad(midiNote: 79, label: "Sol↑"), // G5
            Pad(midiNote: 81, label: "La↑"),  // A5
        ],
        isBuiltIn: true
    )

    static let builtIns: [Preset] = [.cMajor, .aMinor, .pentatonic]
}
