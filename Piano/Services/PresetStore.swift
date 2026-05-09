import Foundation

/// Preset 持久化：自訂 preset 與目前選擇 ID 寫到 Documents/presets.json。
/// 內建 preset 由程式碼提供，不寫檔。
final class PresetStore: ObservableObject {

    @Published private(set) var presets: [Preset] = []
    @Published var currentID: UUID

    private let fileURL: URL
    private let currentIDKey = "currentPresetID"

    struct Snapshot: Codable {
        var customPresets: [Preset]
    }

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = docs.appendingPathComponent("presets.json")

        let custom = Self.loadCustom(from: fileURL)
        let all = Preset.builtIns + custom

        if let saved = UserDefaults.standard.string(forKey: currentIDKey),
           let uuid = UUID(uuidString: saved),
           all.contains(where: { $0.id == uuid }) {
            currentID = uuid
        } else {
            currentID = Preset.builtIns[0].id
        }
        presets = all
    }

    var current: Preset {
        presets.first { $0.id == currentID } ?? Preset.builtIns[0]
    }

    func select(_ id: UUID) {
        guard presets.contains(where: { $0.id == id }) else { return }
        currentID = id
        UserDefaults.standard.set(id.uuidString, forKey: currentIDKey)
    }

    /// 更新目前 preset 的 pads（在編輯模式下使用）。內建 preset 會被複製成自訂版本。
    func updateCurrentPads(_ pads: [Pad]) {
        let cur = current
        if cur.isBuiltIn {
            let copy = Preset(name: "\(cur.name) (自訂)", pads: pads, isBuiltIn: false)
            var customs = customPresets()
            customs.append(copy)
            persist(customs)
            presets = Preset.builtIns + customs
            select(copy.id)
        } else {
            var customs = customPresets()
            if let idx = customs.firstIndex(where: { $0.id == cur.id }) {
                customs[idx].pads = pads
                persist(customs)
                presets = Preset.builtIns + customs
            }
        }
    }

    func rename(_ id: UUID, to name: String) {
        var customs = customPresets()
        guard let idx = customs.firstIndex(where: { $0.id == id }) else { return }
        customs[idx].name = name
        persist(customs)
        presets = Preset.builtIns + customs
    }

    func delete(_ id: UUID) {
        var customs = customPresets()
        customs.removeAll { $0.id == id }
        persist(customs)
        presets = Preset.builtIns + customs
        if currentID == id { select(Preset.builtIns[0].id) }
    }

    // MARK: - Private

    private func customPresets() -> [Preset] {
        presets.filter { !$0.isBuiltIn }
    }

    private func persist(_ customs: [Preset]) {
        let snapshot = Snapshot(customPresets: customs)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private static func loadCustom(from url: URL) -> [Preset] {
        guard let data = try? Data(contentsOf: url),
              let snap = try? JSONDecoder().decode(Snapshot.self, from: data) else {
            return []
        }
        return snap.customPresets
    }
}
