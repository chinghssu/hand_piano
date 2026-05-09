import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings = SettingsStore.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("按鍵大小") {
                    HStack {
                        Text("縮放")
                        Slider(value: $settings.padScale, in: 0.6...1.6)
                        Text(String(format: "%.0f%%", settings.padScale * 100))
                            .frame(width: 56, alignment: .trailing)
                            .monospacedDigit()
                    }
                }

                Section("觸覺回饋") {
                    HStack {
                        Text("震動強度")
                        Slider(value: $settings.hapticIntensity, in: 0...1)
                        Text(String(format: "%.0f%%", settings.hapticIntensity * 100))
                            .frame(width: 50, alignment: .trailing)
                            .monospacedDigit()
                    }
                }

                Section("推弦") {
                    HStack {
                        Text("靈敏度")
                        Slider(value: $settings.bendSensitivity, in: 30...160)
                        Text("\(Int(settings.bendSensitivity)) px")
                            .frame(width: 60, alignment: .trailing)
                            .monospacedDigit()
                    }
                    HStack {
                        Text("最大半音")
                        Slider(value: $settings.bendMaxSemitones, in: 1...12, step: 1)
                        Text("\(Int(settings.bendMaxSemitones))")
                            .frame(width: 30, alignment: .trailing)
                            .monospacedDigit()
                    }
                }

                Section("力度感應") {
                    Picker("感應模式", selection: $settings.velocityModeRaw) {
                        ForEach(VelocityMode.allCases) { mode in
                            Text(mode.label).tag(mode.rawValue)
                        }
                    }
                    Picker("力度曲線", selection: $settings.velocityCurveRaw) {
                        ForEach(VelocityCurve.allCases) { c in
                            Text(c.label).tag(c.rawValue)
                        }
                    }
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}
