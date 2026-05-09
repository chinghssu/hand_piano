# 任務分解 (Tasks)

依照「先能彈出聲音 → 再加表現力 → 再加自訂與創作工具」的順序進行。
每個 Phase 結束時應該都是**可以執行、可以 demo** 的狀態。

---

## Phase 0：專案初始化
- [x] 0.1 用 Xcode 建立新專案 `Piano`，SwiftUI App、iOS 16+、Swift 5.9+
- [x] 0.2 設定 Bundle ID、簽章
- [x] 0.3 `Info.plist` **鎖定僅橫向** (`UISupportedInterfaceOrientations` 只留 `landscapeLeft` + `landscapeRight`)
- [x] 0.4 加入 `NSMicrophoneUsageDescription` (錄音用) 與 `NSMotionUsageDescription` (加速度計用)
- [x] 0.5 加入 `.gitignore`，初始化 git repo
- [x] 0.6 建立資料夾結構：`Models/`, `Views/`, `ViewModels/`, `Services/`, `Resources/`

## Phase 1：最小可彈奏 MVP
- [x] 1.0 (過渡) 先以 `SineAudioEngine` 出聲（commit f81b159）— 確認觸控/多指/pitch bend 流程，但音色像電子噪音
- [x] 1.1 取得 SoundFont 並放入 `Resources/SoundFonts/`
  - 改用 **GeneralUser GS v1.471**（30MB，授權允許商用與重新散布，比 Salamander lite 安全）
  - 已下載到 `Piano/Resources/SoundFonts/GeneralUser_GS.sf2` + license 檔
  - ✅ 已在 Xcode 加入 `Piano` target
- [x] 1.2 實作 `SamplerAudioEngine` (AVAudioEngine + AVAudioUnitSampler)
  - 載入 SoundFont（program 0 = Acoustic Grand Piano）
  - 實作 `PianoAudioEngine` protocol：`noteOn` / `noteOff` / `pitchBend`
  - `PianoViewModel.init()` 偵測 SF2 是否打包，沒有就 fallback 到 `SineAudioEngine`
  - 設定低延遲 buffer (5ms)
  - ⚠️ 待辦：在 Xcode 把 `SamplerAudioEngine.swift` 拖進 Project Navigator（加入 `Piano` target）
- [x] 1.3 實作最簡 `PadView` (圓形按鈕，按下發聲、放開停聲)
- [x] 1.4 在 `PianoView` 排出 10 顆固定按鍵 (C 大調 1 個八度 ± 1 音)
- [x] 1.5 實機測試延遲與多點觸控（換成 sampler 後重測）
- [x] **里程碑**：能用 10 顆按鍵彈出真實鋼琴音色，持續按住有自然 sustain，放開有 release tail

## Phase 2：表現力 — 力度 + 推弦 + 觸覺 
- [ ] 2.1 用 `UIViewRepresentable` 包 `UIView` 取得 `UITouch.majorRadius` (B 來源)
- [ ] 2.2 實作 `VelocityDetector`：CMMotionManager 100Hz 取樣，計算 50ms 峰值 (A 來源)
- [ ] 2.6 力度映射 → MIDI velocity (30–127)：A/B 固定權重合成，不做校準
- [x] 2.7 推弦偵測：垂直拖曳 → pitch bend MIDI 訊息
- [x] 2.8 多指獨立 channel 分配機制 (每指最多 5 ch)
- [ ] 2.9 實作 `HapticEngine` (Core Haptics)：tap + continuous
- [ ] 2.10 按下時觸發震動，強度跟隨 velocity
- [x] 2.11 推弦時的視覺回饋 (上下箭頭 / 數字)
- [ ] **里程碑**：可推弦、力度有 pp/mf/ff 三段感、震動有感

## Phase 3：自訂與 Preset
- [ ] 3.1 定義 `Pad` / `Preset` 資料模型 + Codable
- [ ] 3.2 實作 `PresetStore` (UserDefaults 或 JSON 檔)
- [ ] 3.3 內建 3 個預設 Preset (C 大調、A 小調、五聲音階)
- [ ] 3.4 編輯模式 UI：拖曳、新增、刪除、改音高
- [ ] 3.5 Preset 切換選單
- [ ] 3.6 設定畫面 `SettingsView`：
  - 震動強度 / 時長
  - 推弦靈敏度 / 最大半音
  - 力度感應模式 (auto / accelerometer / radius / fixed)
  - 力度曲線 (linear / log / soft)
  - 重新校準入口
- [ ] **里程碑**：使用者可自訂並儲存自己的鍵盤佈局

## Phase 4a：單軌錄音與 MIDI 匯出
- [ ] 4a.1 節拍器 (BPM 可調，視覺閃爍 + 音效)
- [ ] 4a.2 Audio 錄音 (AVAudioEngine tap → `.m4a`)
- [ ] 4a.3 MIDI 錄音 (記錄 `MidiEvent` 事件 + 寫 SMF Type 0)
- [ ] 4a.4 錄音播放
- [ ] 4a.5 用 iOS 分享面板匯出檔案
- [ ] **里程碑**：可錄一段、匯出 MIDI 在 GarageBand / Logic 開啟

## Phase 4b：多軌、MusicXML 與 PDF 樂譜
- [ ] 4b.1 定義 `Track` / `Project` 資料模型
- [ ] 4b.2 軌道選擇 UI (旋律 / Bassline 切換)
- [ ] 4b.3 多軌同步播放（錄 Track 2 時聽 Track 1）
- [ ] 4b.4 多軌面板：Mute / Solo / 音量 / 重錄
- [ ] 4b.5 倒數 1 小節再開始錄音
- [ ] 4b.6 量化器：MIDI 事件 → 最近的 16/32 分音符
- [ ] 4b.7 實作 `MusicXMLWriter` (純 Swift，組 XML)
  - 雙 staff (treble + bass)
  - 力度標記 pp/p/mf/f/ff
  - 拍號 / 調號 / BPM
- [ ] 4b.8 整合 Verovio (LGPL) 渲染樂譜
  - 評估：iOS native binding vs WKWebView + verovio.js
- [ ] 4b.9 樂譜預覽畫面 (WKWebView 顯示 SVG)
- [ ] 4b.10 SVG → PDF (PDFKit)
- [ ] 4b.11 匯出選單：MIDI / MusicXML / PDF / Audio
- [ ] **里程碑**：旋律 + bassline 雙軌可播放，匯出 PDF 樂譜在 MuseScore 可開啟

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
| 2 表現力 (含校準) | 4 天 |
| 3 自訂 | 3 天 |
| 4a 單軌錄音 | 3 天 |
| 4b 多軌 + 樂譜 | 5–7 天 |
| 5 打磨上架 | 2–4 天 |

## 開發順序原則
1. 每個 Phase 完成後**實機測試**才往下走
2. 音訊延遲一旦發現 > 20ms 就要立刻處理，不要拖到後期
3. 採取**最小變更原則**修改程式，避免過度抽象
