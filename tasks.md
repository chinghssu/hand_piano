# 任務分解 (Tasks)

依照「先能彈出聲音 → 再加表現力 → 再加自訂與創作工具」的順序進行。
每個 Phase 結束時應該都是**可以執行、可以 demo** 的狀態。

---

## Phase 0：專案初始化
- [ ] 0.1 用 Xcode 建立新專案 `Piano`，SwiftUI App、iOS 16+、Swift 5.9+
- [ ] 0.2 設定 Bundle ID、簽章、橫向支援
- [ ] 0.3 加入 `.gitignore`，初始化 git repo
- [ ] 0.4 在 `Info.plist` 加入 `NSMicrophoneUsageDescription` (錄音用)
- [ ] 0.5 建立資料夾結構：`Models/`, `Views/`, `ViewModels/`, `Services/`, `Resources/`

## Phase 1：最小可彈奏 MVP
- [ ] 1.1 下載並轉換 Salamander Grand Piano (lite 版) 為 `.sf2`，放入 `Resources/SoundFonts/`
- [ ] 1.2 實作 `AudioEngine` (AVAudioEngine + AVAudioUnitSampler)
  - 載入 SoundFont
  - `noteOn(note, velocity)` / `noteOff(note)`
  - 設定低延遲 buffer
- [ ] 1.3 實作最簡 `PadView` (圓形按鈕，按下發聲、放開停聲)
- [ ] 1.4 在 `PianoView` 排出 10 顆固定按鍵 (C 大調 1 個八度 ± 1 音)
- [ ] 1.5 實機測試延遲與多點觸控
- [ ] **里程碑**：能用 10 顆按鍵彈出鋼琴音

## Phase 2：表現力 — 力度 + 推弦 + 觸覺
- [ ] 2.1 在 `PadView` 用 `UIViewRepresentable` 包一層 `UIView` 以取得 `UITouch.force` / `majorRadius`
- [ ] 2.2 力度映射 → MIDI velocity (30–127)
- [ ] 2.3 推弦偵測：垂直拖曳 → pitch bend MIDI 訊息
- [ ] 2.4 多指獨立 channel 分配機制 (每指最多 5 ch)
- [ ] 2.5 實作 `HapticEngine` (Core Haptics)：tap + continuous
- [ ] 2.6 按下時觸發震動，強度跟隨 velocity
- [ ] 2.7 推弦時的視覺回饋 (上下箭頭 / 數字)
- [ ] **里程碑**：可推弦、力度有變化、震動有感

## Phase 3：自訂與 Preset
- [ ] 3.1 定義 `Pad` / `Preset` 資料模型 + Codable
- [ ] 3.2 實作 `PresetStore` (UserDefaults 或 JSON 檔)
- [ ] 3.3 內建 3 個預設 Preset (C 大調、A 小調、五聲音階)
- [ ] 3.4 編輯模式 UI：拖曳、新增、刪除、改音高
- [ ] 3.5 Preset 切換選單
- [ ] 3.6 設定畫面 `SettingsView`：
  - 震動強度 / 時長
  - 推弦靈敏度 / 最大半音
  - 力度感應方式 (force / radius)
- [ ] **里程碑**：使用者可自訂並儲存自己的鍵盤佈局

## Phase 4：創作工具
- [ ] 4.1 節拍器 (BPM 可調，視覺閃爍 + 音效)
- [ ] 4.2 Audio 錄音 (AVAudioEngine tap → `.m4a`)
- [ ] 4.3 MIDI 錄音 (記錄事件 + 寫 SMF Type 0)
- [ ] 4.4 錄音播放
- [ ] 4.5 用 iOS 分享面板匯出檔案
- [ ] **里程碑**：可錄一段、匯出 MIDI 在 GarageBand 開啟

## Phase 5：打磨與上架前準備
- [ ] 5.1 App 圖示 / 啟動畫面
- [ ] 5.2 在「關於」頁顯示音色授權聲明
- [ ] 5.3 加入觸覺 fallback (低階機型用 `UIImpactFeedbackGenerator`)
- [ ] 5.4 效能 profile：延遲 < 20ms 驗證
- [ ] 5.5 多機型實測 (iPhone SE / 12 / 15 Pro)
- [ ] 5.6 撰寫 App Store 描述、截圖
- [ ] 5.7 隱私聲明、TestFlight Beta

---

## 預估時程 (僅供參考，實作節奏依你而定)
| Phase | 預估 |
|-------|------|
| 0 初始化 | 0.5 天 |
| 1 MVP | 2 天 |
| 2 表現力 | 3 天 |
| 3 自訂 | 3 天 |
| 4 創作工具 | 3 天 |
| 5 打磨上架 | 2–4 天 |

## 開發順序原則
1. 每個 Phase 完成後**實機測試**才往下走
2. 音訊延遲一旦發現 > 20ms 就要立刻處理，不要拖到後期
3. 採取**最小變更原則**修改程式，避免過度抽象
