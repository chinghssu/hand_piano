import SwiftUI

struct PianoView: View {
    @StateObject private var viewModel = PianoViewModel()
    @ObservedObject private var settings = SettingsStore.shared
    @State private var padStates: [PadState] = []
    @State private var padCenters: [CGPoint] = []
    @State private var padRadius: CGFloat = 44
    @State private var isEditMode = false
    @State private var isSustainOn = false
    @State private var showingSettings = false
    @State private var editingPadIndex: Int? = nil
    @State private var lastGeoSize: CGSize = .zero

    struct PadState {
        var isPressed = false
        var bendSemitones = 0.0
    }

    private let hPad: CGFloat = 16
    private let spacing: CGFloat = 10

    /// 螢幕完整尺寸（由最外層 GeometryReader 提供，已 ignore safe area）
    @State private var screenSize: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(red: 0.06, green: 0.06, blue: 0.10)
                    .ignoresSafeArea(.all)

                padLayer
                    .allowsHitTesting(isEditMode)

                if !isEditMode {
                    touchLayer
                        .frame(width: geo.size.width, height: geo.size.height)
                }

                controlsOverlay
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .onAppear {
                screenSize = geo.size
                lastGeoSize = geo.size
                updateLayout()
            }
            .onChange(of: geo.size) { newSize in
                screenSize = newSize
                lastGeoSize = newSize
                updateLayout()
            }
            .onChange(of: isSustainOn) { newVal in viewModel.setSustain(newVal) }
            .onChange(of: viewModel.presetStore.currentID) { _ in
                editingPadIndex = nil
                updateLayout()
            }
            .onChange(of: viewModel.pads.count) { _ in
                updateLayout()
            }
            .onChange(of: settings.padScale) { _ in
                padRadius = sideWithScale() / 2
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(item: noteEditorBinding) { wrapper in
                NoteEditorSheet(
                    pad: viewModel.pads[wrapper.value],
                    onChange: { newNote, newLabel in
                        var pad = viewModel.pads[wrapper.value]
                        pad.midiNote = newNote
                        pad.label = newLabel
                        viewModel.pads[wrapper.value] = pad
                        viewModel.savePadsToPreset()
                    }
                )
            }
        }
        .ignoresSafeArea(.all)
    }

    private var noteEditorBinding: Binding<IndexWrapper?> {
        Binding(
            get: { editingPadIndex.map { IndexWrapper(value: $0) } },
            set: { editingPadIndex = $0?.value }
        )
    }
    struct IndexWrapper: Identifiable {
        let value: Int
        var id: Int { value }
    }

    // MARK: - Visual layer

    private var padLayer: some View {
        ZStack {
            ForEach(viewModel.pads.indices, id: \.self) { i in
                if i < padCenters.count && i < padStates.count {
                    ZStack(alignment: .topTrailing) {
                        PadView(
                            pad: viewModel.pads[i],
                            isPressed: padStates[i].isPressed,
                            bendSemitones: padStates[i].bendSemitones,
                            isEditMode: isEditMode
                        )
                        .frame(width: padRadius * 2, height: padRadius * 2)
                        .onTapGesture {
                            guard isEditMode else { return }
                            editingPadIndex = i
                        }

                        if isEditMode {
                            Button {
                                deletePad(at: i)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(.red, .white)
                            }
                            .offset(x: 8, y: -8)
                        }
                    }
                    .position(padCenters[i])
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                guard isEditMode else { return }
                                padCenters[i] = value.location
                            }
                            .onEnded { _ in
                                guard isEditMode else { return }
                                savePositions()
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
                let semitones = Double(origin.y - current.y) / viewModel.bendSensitivity
                let maxBend = viewModel.bendMaxSemitones
                let clamped = max(-maxBend, min(maxBend, semitones))
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
            HStack(spacing: 10) {
                Button(action: { isSustainOn.toggle() }) {
                    Text(isSustainOn ? "延音 ON" : "延音")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isSustainOn ? .black : .white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(isSustainOn ? Color.white : Color.white.opacity(0.15))
                        .clipShape(Capsule())
                }

                PresetMenuView(store: viewModel.presetStore)

                Spacer()

                if isEditMode {
                    Button(action: { addPad() }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.white)
                    }
                }

                Button(action: { showingSettings = true }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.15))
                        .clipShape(Capsule())
                }

                Button(action: toggleEdit) {
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

    private func toggleEdit() {
        if isEditMode {
            viewModel.savePadsToPreset()
        }
        isEditMode.toggle()
        editingPadIndex = nil
    }

    // MARK: - Edit actions

    private func addPad() {
        let baseNote = viewModel.pads.last?.midiNote ?? 60
        let newNote = UInt8(min(127, Int(baseNote) + 2))
        let pad = Pad(midiNote: newNote, label: noteLabel(for: newNote))
        viewModel.pads.append(pad)
        padStates.append(PadState())
        padCenters.append(CGPoint(x: screenSize.width / 2, y: screenSize.height / 2))
        viewModel.savePadsToPreset()
        savePositions()
    }

    private func deletePad(at index: Int) {
        guard viewModel.pads.indices.contains(index) else { return }
        viewModel.pads.remove(at: index)
        if padStates.indices.contains(index) { padStates.remove(at: index) }
        if padCenters.indices.contains(index) { padCenters.remove(at: index) }
        viewModel.savePadsToPreset()
        savePositions()
    }

    private func noteLabel(for note: UInt8) -> String {
        let names = ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"]
        return names[Int(note) % 12]
    }

    // MARK: - Layout

    private func baseSide() -> CGFloat {
        let perRow = max(5, Int(ceil(Double(viewModel.pads.count) / 2.0)))
        let n = CGFloat(perRow)
        let usable = screenSize.width - hPad * 2 - spacing * (n - 1)
        return min(usable / n, screenSize.height * 0.42)
    }

    private func sideWithScale() -> CGFloat {
        let scale = CGFloat(SettingsStore.shared.padScale)
        return max(40, min(screenSize.height * 0.7, baseSide() * scale))
    }

    private func updateLayout() {
        let perRow = max(5, Int(ceil(Double(viewModel.pads.count) / 2.0)))
        let side = sideWithScale()

        padRadius = side / 2

        if let saved = loadPositions() {
            padCenters = saved
        } else {
            padCenters = defaultCenters(side: side, perRow: perRow)
        }

        if padStates.count != viewModel.pads.count {
            padStates = Array(repeating: PadState(), count: viewModel.pads.count)
        }
    }

    private func defaultCenters(side: CGFloat, perRow: Int) -> [CGPoint] {
        let n = CGFloat(perRow)
        let totalW = side * n + spacing * (n - 1)
        let startX = (screenSize.width - totalW) / 2 + side / 2
        let row1Y = screenSize.height * 0.32
        let row2Y = row1Y + side + 16

        return viewModel.pads.indices.map { i in
            let col = i % perRow
            let row = i / perRow
            let x = startX + CGFloat(col) * (side + spacing)
            let y = row == 0 ? row1Y : row2Y
            return CGPoint(x: x, y: y)
        }
    }

    // MARK: - Persistence (per-preset)

    private var positionsKey: String {
        "padPositions.\(viewModel.presetStore.currentID.uuidString)"
    }

    private func savePositions() {
        let normalized = padCenters.map {
            [$0.x / screenSize.width, $0.y / screenSize.height]
        }
        UserDefaults.standard.set(normalized, forKey: positionsKey)
    }

    private func loadPositions() -> [CGPoint]? {
        guard let data = UserDefaults.standard.array(forKey: positionsKey) as? [[Double]],
              data.count == viewModel.pads.count else { return nil }
        return data.map { CGPoint(x: $0[0] * screenSize.width, y: $0[1] * screenSize.height) }
    }
}

// MARK: - NoteEditorSheet

private struct NoteEditorSheet: View {
    let pad: Pad
    let onChange: (UInt8, String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var note: Double
    @State private var label: String

    init(pad: Pad, onChange: @escaping (UInt8, String) -> Void) {
        self.pad = pad
        self.onChange = onChange
        _note = State(initialValue: Double(pad.midiNote))
        _label = State(initialValue: pad.label)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("音高") {
                    HStack {
                        Text(noteName(UInt8(note)))
                            .font(.system(size: 18, weight: .semibold, design: .monospaced))
                            .frame(width: 64, alignment: .leading)
                        Slider(value: $note, in: 21...108, step: 1)
                        Text("\(Int(note))")
                            .frame(width: 36, alignment: .trailing)
                            .monospacedDigit()
                    }
                }
                Section("標籤") {
                    TextField("Do / Re / Mi …", text: $label)
                }
            }
            .navigationTitle("編輯音高")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("儲存") {
                        onChange(UInt8(note), label.isEmpty ? noteName(UInt8(note)) : label)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func noteName(_ n: UInt8) -> String {
        let names = ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"]
        let octave = Int(n) / 12 - 1
        return "\(names[Int(n) % 12])\(octave)"
    }
}
