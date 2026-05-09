import SwiftUI

struct PianoView: View {
    @StateObject private var viewModel = PianoViewModel()
    @State private var padStates: [PadState] = Array(repeating: PadState(), count: 10)
    @State private var padCenters: [CGPoint] = []
    @State private var padRadius: CGFloat = 44
    @State private var isEditMode = false
    @State private var isSustainOn = false

    struct PadState {
        var isPressed = false
        var bendSemitones = 0.0
    }

    private let hPad: CGFloat = 16
    private let spacing: CGFloat = 10
    private let positionsKey = "padPositions"

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(red: 0.06, green: 0.06, blue: 0.10).ignoresSafeArea()

                padLayer(geo: geo)
                    .allowsHitTesting(isEditMode)

                if !isEditMode {
                    touchLayer
                        .frame(width: geo.size.width, height: geo.size.height)
                }

                controlsOverlay
            }
            .onAppear { updateLayout(geo: geo) }
            .onChange(of: geo.size) { _ in updateLayout(geo: geo) }
            .onChange(of: isSustainOn) { newVal in viewModel.setSustain(newVal) }
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
                        bendSemitones: padStates[i].bendSemitones,
                        isEditMode: isEditMode
                    )
                    .frame(width: padRadius * 2, height: padRadius * 2)
                    .position(padCenters[i])
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                guard isEditMode else { return }
                                padCenters[i] = value.location
                            }
                            .onEnded { _ in
                                guard isEditMode else { return }
                                savePositions(geo: geo)
                            }
                    )
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
                                     touchId: touchId,
                                     majorRadius: majorRadius)
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

    // MARK: - Controls

    private var controlsOverlay: some View {
        VStack {
            HStack {
                Button(action: { isSustainOn.toggle() }) {
                    Text(isSustainOn ? "延音 ON" : "延音")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isSustainOn ? .black : .white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(isSustainOn ? Color.white : Color.white.opacity(0.15))
                        .clipShape(Capsule())
                }
                Spacer()
                Button(action: { isEditMode.toggle() }) {
                    Text(isEditMode ? "完成" : "編輯")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isEditMode ? .black : .white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(isEditMode ? Color.yellow : Color.white.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            Spacer()
        }
    }

    // MARK: - Layout

    private func updateLayout(geo: GeometryProxy) {
        let perRow = 5
        let n = CGFloat(perRow)
        let usable = geo.size.width - hPad * 2 - spacing * (n - 1)
        let side = min(usable / n, geo.size.height * 0.38)

        padRadius = side / 2

        if let saved = loadPositions(geo: geo) {
            padCenters = saved
        } else {
            padCenters = defaultCenters(geo: geo, side: side)
        }

        if padStates.count != viewModel.pads.count {
            padStates = Array(repeating: PadState(), count: viewModel.pads.count)
        }
    }

    private func defaultCenters(geo: GeometryProxy, side: CGFloat) -> [CGPoint] {
        let perRow = 5
        let n = CGFloat(perRow)
        let totalW = side * n + spacing * (n - 1)
        let startX = (geo.size.width - totalW) / 2 + side / 2
        let row1Y = geo.size.height * 0.32
        let row2Y = row1Y + side + 16

        return viewModel.pads.indices.map { i in
            let col = i % perRow
            let row = i / perRow
            let x = startX + CGFloat(col) * (side + spacing)
            let y = row == 0 ? row1Y : row2Y
            return CGPoint(x: x, y: y)
        }
    }

    // MARK: - Persistence

    private func savePositions(geo: GeometryProxy) {
        let normalized = padCenters.map { [$0.x / geo.size.width, $0.y / geo.size.height] }
        UserDefaults.standard.set(normalized, forKey: positionsKey)
    }

    private func loadPositions(geo: GeometryProxy) -> [CGPoint]? {
        guard let data = UserDefaults.standard.array(forKey: positionsKey) as? [[Double]],
              data.count == viewModel.pads.count else { return nil }
        return data.map { CGPoint(x: $0[0] * geo.size.width, y: $0[1] * geo.size.height) }
    }
}
