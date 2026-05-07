import Foundation
import SwiftUI

struct Pad: Identifiable, Codable {
    let id: UUID
    var midiNote: UInt8
    var label: String
    var colorComponents: ColorComponents

    init(id: UUID = UUID(), midiNote: UInt8, label: String,
         colorComponents: ColorComponents = .defaultPad) {
        self.id = id
        self.midiNote = midiNote
        self.label = label
        self.colorComponents = colorComponents
    }

    var frequency: Double {
        440.0 * pow(2.0, (Double(midiNote) - 69.0) / 12.0)
    }

    var noteName: String {
        let names = ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"]
        let octave = Int(midiNote) / 12 - 1
        return "\(names[Int(midiNote) % 12])\(octave)"
    }
}

struct ColorComponents: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double

    var color: Color { Color(red: red, green: green, blue: blue) }

    static let defaultPad = ColorComponents(red: 0.20, green: 0.47, blue: 0.90)
}

extension Pad {
    // B3 Do Re Mi Fa Sol La Si Do Re (低Si → 高Re)
    static let cMajorDefault: [Pad] = [
        Pad(midiNote: 59, label: "Si↓"),
        Pad(midiNote: 60, label: "Do"),
        Pad(midiNote: 62, label: "Re"),
        Pad(midiNote: 64, label: "Mi"),
        Pad(midiNote: 65, label: "Fa"),
        Pad(midiNote: 67, label: "Sol"),
        Pad(midiNote: 69, label: "La"),
        Pad(midiNote: 71, label: "Si"),
        Pad(midiNote: 72, label: "Do↑"),
        Pad(midiNote: 74, label: "Re↑"),
    ]
}
