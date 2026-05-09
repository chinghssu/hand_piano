import SwiftUI

/// 頂部 toolbar 用的 Preset 選單 (Menu 樣式)。
struct PresetMenuView: View {
    @ObservedObject var store: PresetStore
    @State private var renamingID: UUID?
    @State private var renameText: String = ""
    @State private var showingRename = false

    var body: some View {
        Menu {
            Section("內建") {
                ForEach(store.presets.filter { $0.isBuiltIn }) { preset in
                    presetButton(preset)
                }
            }
            let custom = store.presets.filter { !$0.isBuiltIn }
            if !custom.isEmpty {
                Section("自訂") {
                    ForEach(custom) { preset in
                        Menu(preset.name) {
                            Button("選用") { store.select(preset.id) }
                            Button("重新命名") {
                                renamingID = preset.id
                                renameText = preset.name
                                showingRename = true
                            }
                            Button("刪除", role: .destructive) {
                                store.delete(preset.id)
                            }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(store.current.name)
                    .font(.system(size: 14, weight: .semibold))
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.15))
            .clipShape(Capsule())
        }
        .alert("重新命名", isPresented: $showingRename) {
            TextField("名稱", text: $renameText)
            Button("取消", role: .cancel) {}
            Button("儲存") {
                if let id = renamingID, !renameText.isEmpty {
                    store.rename(id, to: renameText)
                }
            }
        }
    }

    @ViewBuilder
    private func presetButton(_ preset: Preset) -> some View {
        Button {
            store.select(preset.id)
        } label: {
            if preset.id == store.currentID {
                Label(preset.name, systemImage: "checkmark")
            } else {
                Text(preset.name)
            }
        }
    }
}
