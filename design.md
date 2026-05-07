# 設計文件 (Design)

## 1. 技術架構總覽

```
┌─────────────────────────────────────────────────────┐
│                  SwiftUI View Layer                 │
│  PianoView ─ PadView ─ SettingsView ─ RecorderView  │
└──────────────────┬──────────────────────────────────┘
                   │ @Observable / Bindings
┌──────────────────▼──────────────────────────────────┐
│                  ViewModel Layer                    │
│   PianoEngineVM    SettingsVM    RecorderVM         │
└──────────────────┬──────────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────────┐
│                  Service Layer                      │
│  AudioEngine    HapticEngine   PresetStore   MIDI   │
│  (AVAudioEngine)(CHHapticEngine)(UserDefaults)(...) │
└─────────────────────────────────────────────────────┘
```

## 2. 模組設計

### 2.1 AudioEngine (音訊引擎)
- 基於 `AVAudioEngine` + `AVAudioUnitSampler`
- 載入 SoundFont (`.sf2`) 或 EXS 取樣
- API：
  ```swift
  func noteOn(note: UInt8, velocity: UInt8, channel: UInt8 = 0)
  func noteOff(note: UInt8, channel: UInt8 = 0)
  func pitchBend(value: UInt16, channel: UInt8 = 0)  // 0-16383, 中點 8192
  ```
- 每根手指分配一個獨立的 MIDI channel (0–4)，這樣不同手指推弦不會互相影響
- 設定 `preferredIOBufferDuration = 0.005` (5ms) 以降低延遲

### 2.2 HapticEngine (觸覺回饋)
- 使用 `CHHapticEngine` (Core Haptics)
- 支援**強度 (intensity)** 與**銳利度 (sharpness)** 對應觸碰力度
- API：
  ```swift
  func playTap(intensity: Float, duration: TimeInterval)
  func playContinuous(intensity: Float)  // 推弦時持續微震
  func stopContinuous()
  ```
- 自訂模式：使用 `CHHapticPattern` JSON 檔可讓使用者切換不同手感

### 2.3 Pad (虛擬按鍵)
- SwiftUI `Canvas` + `DragGesture(minimumDistance: 0)` 偵測
- 狀態：
  ```swift
  struct PadState {
      var isPressed: Bool
      var pressLocation: CGPoint     // 按壓點
      var dragOffset: CGSize         // 推弦位移
      var radius: CGFloat            // 觸碰半徑 → velocity
      var fingerId: Int              // 對應 MIDI channel
  }
  ```
- 推弦計算：
  - 垂直拖曳超過 30pt → 觸發 pitch bend
  - 最大拖曳 80pt 對應 ±1 semitone (使用者可調)
  - 線性映射到 MIDI pitch bend 值 (0–16383)
- 力度計算：
  - 優先使用 `UITouch.force` (3D Touch / Apple Pencil)
  - 後備：使用 `UITouch.majorRadius` 估算
  - 映射 velocity 30–127 (避免過小聽不見)

### 2.4 PadLayout (版面配置)
- 資料模型：
  ```swift
  struct Pad: Identifiable, Codable {
      let id: UUID
      var midiNote: UInt8       // 60 = C4
      var position: CGPoint     // 相對螢幕比例 (0-1)
      var size: CGFloat         // 半徑 (pt)
      var color: Color
      var label: String         // "Do", "Re" ...
  }

  struct Preset: Identifiable, Codable {
      let id: UUID
      var name: String
      var pads: [Pad]
  }
  ```
- **預設 Preset**：C 大調 10 鍵 (B3, C4, D4, E4, F4, G4, A4, B4, C5, D5)
- 儲存：JSON → `UserDefaults` 或 `Documents/presets/`

### 2.5 編輯模式 (Edit Mode)
- 切換為編輯模式後：
  - 按鍵變半透明，顯示拖曳把手
  - 長按按鍵彈出選單：刪除 / 改音高 / 改顏色 / 改大小
  - 空白處 + 號可新增按鍵
  - 完成後儲存為當前 Preset

### 2.6 Recorder (錄音器)
- 兩種模式：
  - **Audio**：`AVAudioEngine` 接 tap 寫入 `AVAudioFile` (`.m4a`)
  - **MIDI**：自行記錄 `(timestamp, noteOn/Off, note, velocity, pitchBend)` 事件，匯出為標準 MIDI File (Type 0)
- 使用 `MIDIPacketList` 或自行寫 SMF binary
- 節拍器：`AVAudioEngine` schedule 短促 click 取樣

## 3. UI 草圖 (橫向)

```
┌────────────────────────────────────────────────────────┐
│ ▶ REC  ⏸  00:12   BPM:120  ♩  [Preset: C Major ▼] ⚙  │
├────────────────────────────────────────────────────────┤
│                                                        │
│   ⬤    ⬤    ⬤    ⬤    ⬤    ⬤    ⬤    ⬤    ⬤    ⬤   │
│   B3   C4   D4   E4   F4   G4   A4   B4   C5   D5    │
│   Si   Do   Re   Mi   Fa   So   La   Si   Do   Re    │
│                                                        │
│        (按下變亮 + 漣漪 + 上下滑動推弦顯示 ±)         │
└────────────────────────────────────────────────────────┘
```

## 4. 互動流程

### 4.1 彈奏流程
1. 使用者手指按下 Pad → 取得 `force` / `radius` → 計算 velocity
2. 同時觸發：
   - `AudioEngine.noteOn(note, velocity)`
   - `HapticEngine.playTap(intensity: velocity/127, duration: settings.tapDuration)`
   - UI 動畫
3. 手指滑動 → 計算 pitch bend → `AudioEngine.pitchBend(value)`
4. 手指離開 → `AudioEngine.noteOff(note)` + 結束動畫

### 4.2 編輯流程
1. 點擊右上 ⚙ 進入設定 → 「編輯按鍵」
2. 進入編輯模式 → 拖曳 / 長按改設定 / + 新增
3. 「儲存」→ 寫入 Preset

## 5. 開源音色採用方案
- **首選**：Salamander Grand Piano V3 (CC BY 3.0)
  - 原始格式 SFZ → 用 Polyphone 工具轉為 SF2
  - 完整版約 1.7 GB；提供精簡版 (~200 MB) 給 App 內建
- **檔案位置**：`Resources/SoundFonts/SalamanderGrand_lite.sf2`
- 設定檔載入：
  ```swift
  sampler.loadSoundBankInstrument(at: url, program: 0,
      bankMSB: 0x79, bankLSB: 0)
  ```

## 6. 風險與對策
| 風險 | 對策 |
|------|------|
| 觸控延遲過高 | 降低 buffer、預先 warm up sampler、避免主執行緒阻塞 |
| `UITouch.force` 在新 iPhone (無 3D Touch) 失效 | Fallback 用 `majorRadius` + 觸碰時間 |
| 多指推弦互相干擾 | 每指分配獨立 MIDI channel |
| SoundFont 太大 | 提供精簡版本 + 之後可從雲端下載完整版 |
| Core Haptics 在低階機型表現差 | 提供「簡易震動」fallback (`UIImpactFeedbackGenerator`) |
