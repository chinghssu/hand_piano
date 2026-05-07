import SwiftUI

struct PadView: View {
    let pad: Pad
    var isPressed: Bool = false
    var bendSemitones: Double = 0.0

    private var padColor: Color { pad.colorComponents.color }

    var body: some View {
        ZStack {
            Circle()
                .fill(padColor.opacity(isPressed ? 1.0 : 0.55))
                .overlay(Circle().strokeBorder(Color.white.opacity(0.25), lineWidth: 1.5))
                .shadow(color: padColor.opacity(isPressed ? 0.85 : 0.2),
                        radius: isPressed ? 22 : 6)
                .scaleEffect(isPressed ? 1.10 : 1.0)
                .animation(.spring(duration: 0.08, bounce: 0.3), value: isPressed)

            VStack(spacing: 3) {
                bendIndicator
                Text(pad.label)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(pad.noteName)
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
    }

    @ViewBuilder
    private var bendIndicator: some View {
        if abs(bendSemitones) > 0.05 {
            HStack(spacing: 2) {
                Image(systemName: bendSemitones > 0 ? "arrow.up" : "arrow.down")
                    .font(.system(size: 9, weight: .bold))
                Text(String(format: "%.1f", abs(bendSemitones)))
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
            }
            .foregroundStyle(.white.opacity(0.85))
        }
    }
}
