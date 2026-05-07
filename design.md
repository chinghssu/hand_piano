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
│  AudioEngine   HapticEngine   VelocityDetector      │
│  PresetStore   MIDIWriter     MusicXMLWriter        │
│  ScoreRenderer (Verovio)      MultiTrackRecorder    │
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
- 力度計算：交給 `VelocityDetector` 模組（見 §2.3.1）

### 2.3.1 VelocityDetector (力度偵測 — A+B 雙來源)

雙來源混合偵測，根據裝置狀態自動切換主來源：

```swift
final class VelocityDetector {
    // A. 加速度計 — 主要
    private let motion = CMMotionManager()
    private var recentAccelerationPeak: Double = 0  // 最近 50ms 的峰值

    // B. 觸碰半徑 — 後備
    func radiusVelocity(touch: UITouch) -> Double {
        return Double(touch.majorRadius)
    }

    // 情境偵測：是否手持
    private var isHandheld: Bool {
        // 重力以外的加速度持續 > threshold → 手持
    }

    // 主入口：拿到 touch 時呼叫
    func computeVelocity(touch: UITouch) -> UInt8 {
        let raw: Double
        if isHandheld {
            raw = recentAccelerationPeak                      // A 為主
        } else {
            raw = radiusVelocity(touch: touch)                // B 為主
        }
        return mapToMIDI(raw, using: userCalibration)         // 套使用者校準曲線
    }
}
```

**加速度計細節**：
- `startDeviceMotionUpdates(to:)` 以 100Hz 取樣 `userAcceleration`
- 取最近 50ms 內 `|a|` 的峰值當作敲擊力道
- 為避免重複觸發：每次 `noteOn` 後 80ms 內忽略新峰值
- 純放桌面時加速度幾乎為 0 → 自動 fallback 到半徑

**校準流程** (`CalibrationView`)：
1. 引導使用者「請輕敲 3 次」→ 收集 3 個 raw 值取平均 = `softAvg`
2. 引導使用者「請大力敲 3 次」→ 收集 3 個 raw 值取平均 = `loudAvg`
3. 建立線性映射：`softAvg → velocity 40`，`loudAvg → velocity 110`
4. 校準資料儲存於 `UserDefaults`，可隨時重做

**設定選項**：
- `velocityMode`：`.auto` (推薦) / `.accelerometer` / `.radius` / `.fixed(value)`
- `velocityCurve`：linear / logarithmic / soft (可調)

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

#### 2.6.1 Phase 4a — 單軌
- 兩種輸出：
  - **Audio**：`AVAudioEngine` 接 tap 寫入 `AVAudioFile` (`.m4a`)
  - **MIDI**：自行記錄 `(timestamp, noteOn/Off, note, velocity, pitchBend)` 事件，匯出為 SMF Type 0
- 節拍器：`AVAudioEngine` schedule 短促 click 取樣

#### 2.6.2 Phase 4b — 多軌 (旋律 + Bassline)

```swift
struct MidiEvent {
    let time: TimeInterval        // 相對於錄音開始
    let type: EventType           // .noteOn / .noteOff / .pitchBend
    let note: UInt8?
    let velocity: UInt8?
    let pitchBend: UInt16?
}

struct Track: Identifiable, Codable {
    let id: UUID
    var name: String              // "旋律" / "Bassline"
    var clef: Clef                // .treble / .bass
    var events: [MidiEvent]
    var isMuted: Bool
    var isSolo: Bool
    var volume: Float             // 0-1
}

struct Project: Codable {
    var tracks: [Track]           // 本期最多 2 軌
    var bpm: Double
    var timeSignature: (Int, Int)
    var key: String               // "C major"
}
```

**錄音流程**：
1. 選擇要錄的 Track (旋律 / Bassline)
2. 點 ⏺ 開始錄 → 節拍器倒數 1 小節 → 開始記錄事件
3. 此時其他 Track 同步播放（可監聽 / 對拍）
4. 點 ⏹ 停止 → 寫入 `Track.events`

**多軌播放**：使用 `AVAudioEngine` 多個 sampler node，每軌一條，依事件 timestamp `scheduleMIDI` 觸發。

### 2.7 樂譜輸出 (Phase 4b)

#### MusicXMLWriter
- 純 Swift 實作，把 `Project` 轉為 MusicXML 4.0 格式
- 處理：音高、時值量化（最小 16 分音符）、力度標記 (pp/p/mf/f/ff)、雙 staff (treble + bass)
- 推弦轉為 MusicXML 的 `<bend>` 標記 (吉他常用)，或忽略 (鋼琴譜)

#### ScoreRenderer (Verovio)
- 使用 [verovio.humdrum.org](https://www.verovio.org/) 的 iOS binding (LGPL)
- 流程：MusicXML 字串 → `Verovio.loadData()` → `renderToSVG(page:)` → SVG 字串
- SVG 顯示在 `WKWebView` (預覽) 或轉 PDF：
  - 用 `WKWebView` 載入 SVG → `createPDF(configuration:)` 產生 PDF
- 輸出 `.pdf` 透過 iOS 分享面板

## 3. UI 草圖 (僅橫向，鎖定 landscape)

### 3.1 主畫面
```
┌──────────────────────────────────────────────────────────┐
│ ⏺ ⏸ ⏹ 00:12  BPM:120  4/4  [Preset:C Major▼] [Track:旋律▼] ⚙│
├──────────────────────────────────────────────────────────┤
│                                                          │
│   ⬤    ⬤    ⬤    ⬤    ⬤    ⬤    ⬤    ⬤    ⬤    ⬤    │
│   B3   C4   D4   E4   F4   G4   A4   B4   C5   D5      │
│   Si   Do   Re   Mi   Fa   So   La   Si   Do   Re      │
│                                                          │
│        (按下變亮 + 漣漪 + 上下滑動推弦顯示 ±)            │
└──────────────────────────────────────────────────────────┘
```

### 3.2 多軌面板 (Phase 4b)
```
┌──────────────────────────────────────────────────────────┐
│ Track 1 旋律 (treble)    [M][S]  ▮▮▮▮▮▯▯▯  ⏺ 已錄        │
│ Track 2 Bassline (bass)  [M][S]  ▯▯▯▯▯▯▯▯  ⏺ 待錄        │
│                          [預覽樂譜] [匯出 MIDI/XML/PDF]   │
└──────────────────────────────────────────────────────────┘
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
| 加速度計在桌面上失效 | 自動 fallback 到觸碰半徑 (B 來源) |
| 不同人手指敲擊習慣差異大 | 強制首次啟動執行校準流程 |
| Verovio 體積大 / 整合複雜 | 先用 WKWebView + verovio.js 驗證可行，必要時改 native |
| MusicXML 量化造成節奏失真 | 提供「量化精度」設定 (16/32 分音符)，原始 MIDI 保留不量化 |
| 多指推弦互相干擾 | 每指分配獨立 MIDI channel |
| SoundFont 太大 | 提供精簡版本 + 之後可從雲端下載完整版 |
| Core Haptics 在低階機型表現差 | 提供「簡易震動」fallback (`UIImpactFeedbackGenerator`) |
