import SwiftUI

struct PianoView: View {
    @State private var viewModel = PianoViewModel()
    @State private var padStates: [PadState] = Array(repeating: PadState(), count: 10)
    @State private var padCenters: [CGPoint] = []
    @State private var padRadius: CGFloat = 44

    struct PadState {
        var isPressed = false
        var bendSemitones = 0.0
    }

    private let hPad: CGFloat = 24
    private let spacing: CGFloat = 14

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(red: 0.06, green: 0.06, blue: 0.10).ignoresSafeArea()

                padLayer(geo: geo).allowsHitTesting(false)

                touchLayer
                    .frame(width: geo.size.width, height: geo.size.height)
            }
            .onAppear { updateLayout(geo: geo) }
            .onChange(of: geo.size) { updateLayout(geo: geo) }
        }
    }

    // MARK: - Visual layer

    private func padLayer(geo: GeometryProxy) -> some View {
        ZStack {
            ForEach(viewModel.pads.indices, id: \.self) { i in
                if i < padCenters.count {
                    PadView(
                        pad: viewModel.pads[i],
                        isPressed: padStates[i].isPressed,
                        bendSemitones: padStates[i].bendSemitones
                    )
                    .frame(width: padRadius * 2, height: padRadius * 2)
                    .position(padCenters[i])
                }
            }
        }
    }

    // MARK: - Touch layer

    private var touchLayer: some View {
        TouchOverlayView(
            padCenters: padCenters,
            padRadius: padRadius,
            onBegan: { index, touchId, _, majorRadius in
                guard index < padStates.count else { return }
                padStates[index].isPressed = true
                padStates[index].bendSemitones = 0
                viewModel.touchBegan(on: viewModel.pads[index],
                                     velocity: velocityFrom(radius: majorRadius),
                                     touchId: touchId)
            },
            onMoved: { index, touchId, current, origin in
                guard index < padStates.count else { return }
                let semitones = Double(origin.y - current.y) / 80.0
                let clamped = max(-2.0, min(2.0, semitones))
                padStates[index].bendSemitones = clamped
                viewModel.updatePitchBend(semitones: clamped, touchId: touchId)
            },
            onEnded: { index, touchId in
                guard index < padStates.count else { return }
                padStates[index].isPressed = false
                padStates[index].bendSemitones = 0
                viewModel.touchEnded(on: viewModel.pads[index], touchId: touchId)
            }
        )
    }

    // MARK: - Layout

    private func updateLayout(geo: GeometryProxy) {
        let n = CGFloat(viewModel.pads.count)
        let usable = geo.size.width - hPad * 2 - spacing * (n - 1)
        let diameter = min(usable / n, geo.size.height * 0.72)
        let r = diameter / 2
        let totalW = diameter * n + spacing * (n - 1)
        let startX = (geo.size.width - totalW) / 2 + r
        let cy = geo.size.height / 2

        padRadius = r
        padCenters = viewModel.pads.indices.map { i in
            CGPoint(x: startX + CGFloat(i) * (diameter + spacing), y: cy)
        }
        if padStates.count != viewModel.pads.count {
            padStates = Array(repeating: PadState(), count: viewModel.pads.count)
        }
    }

    // MARK: - Velocity

    // Phase 1: radius-only. Phase 2 will add accelerometer (A source).
    private func velocityFrom(radius: CGFloat) -> UInt8 {
        let r = Double(radius)
        let clamped = max(10.0, min(45.0, r))
        let v = 30.0 + (clamped - 10.0) / 35.0 * 80.0
        return UInt8(v)
    }
}
