//
//  SettingsView.swift
//  Metafile to ESP Converter for Mac
//
//  Created by Auto-Agent on 2025/12/29.
//

import SwiftUI

/// アプリケーション設定画面
struct SettingsView: View {
    /// プレビューの背景色設定（UserDefaultsに保存）
    /// "white", "gray", "clear" のいずれか
    @AppStorage("previewBackgroundColor") private var selectedColor: String = "white"
    
    var body: some View {
        TabView {
            // 一般設定タブ
            Form {
                Section(header: Text("Appearance")) {
                    Picker("Preview Background", selection: $selectedColor) {
                        Text("White").tag("white")
                        Text("Light Gray").tag("gray")
                        Text("Transparent").tag("clear")
                    }
                    .pickerStyle(.inline)
                    
                    Text("The background color of the preview area when no image is loaded or when the image has transparency.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .tabItem {
                Label("General", systemImage: "gear")
            }
            
            // キーボードショートカット設定タブ
            Form {
                Section(header: Text("Keyboard Shortcuts")) {
                    Text("Click the button to record a new shortcut.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ShortcutRecorder(title: "Paste", key: $pasteKey, modifiers: $pasteModifiers)
                    ShortcutRecorder(title: "Copy", key: $copyKey, modifiers: $copyModifiers)
                    
                    Divider()
                    
                    ShortcutRecorder(title: "Open Metafile", key: $openKey, modifiers: $openModifiers)
                    ShortcutRecorder(title: "Save Metafile", key: $saveKey, modifiers: $saveModifiers)
                    ShortcutRecorder(title: "Export PDF", key: $exportPDFKey, modifiers: $exportPDFModifiers)
                    ShortcutRecorder(title: "Export EPS", key: $exportEPSKey, modifiers: $exportEPSModifiers)
                    
                    Divider()
                    
                    Button("Reset to Defaults") {
                        resetShortcuts()
                    }
                }
            }
            .padding()
            .tabItem {
                Label("Shortcuts", systemImage: "keyboard")
            }
        }
        .frame(width: 500, height: 400)
    }
    
    // MARK: - Shortcut States
    
    @AppStorage("shortcut_paste_key") private var pasteKey: String = "v"
    @AppStorage("shortcut_paste_mod") private var pasteModifiers: Int = 1048576 // Command
    
    @AppStorage("shortcut_copy_key") private var copyKey: String = "c"
    @AppStorage("shortcut_copy_mod") private var copyModifiers: Int = 1048576 // Command
    
    @AppStorage("shortcut_open_key") private var openKey: String = "o"
    @AppStorage("shortcut_open_mod") private var openModifiers: Int = 1048576 // Command
    
    @AppStorage("shortcut_save_key") private var saveKey: String = "s"
    @AppStorage("shortcut_save_mod") private var saveModifiers: Int = 1048576 // Command
    
    @AppStorage("shortcut_export_pdf_key") private var exportPDFKey: String = "e"
    @AppStorage("shortcut_export_pdf_mod") private var exportPDFModifiers: Int = 1048576 // Command
    
    @AppStorage("shortcut_export_eps_key") private var exportEPSKey: String = "p"
    @AppStorage("shortcut_export_eps_mod") private var exportEPSModifiers: Int = 1179648 // Command + Shift (1048576 + 131072)
    
    private func resetShortcuts() {
        pasteKey = "v"; pasteModifiers = 1048576
        copyKey = "c"; copyModifiers = 1048576
        openKey = "o"; openModifiers = 1048576
        saveKey = "s"; saveModifiers = 1048576
        exportPDFKey = "e"; exportPDFModifiers = 1048576
        exportEPSKey = "p"; exportEPSModifiers = 1179648
    }
}

/// ショートカット入力用レコーダー
struct ShortcutRecorder: View {
    let title: String
    @Binding var key: String
    @Binding var modifiers: Int
    
    @State private var isRecording = false
    @FocusState private var isFocused: Bool
    
    var body: some View {
        LabeledContent(title) {
            Button(action: {
                isRecording = true
                isFocused = true
            }) {
                Text(isRecording ? "Press Key..." : shortcutDescription)
                    .frame(minWidth: 80, alignment: .center)
                    .padding(.vertical, 2)
            }
            .buttonStyle(.bordered)
            .tint(isRecording ? .red : .primary)
            .focusable()
            .focused($isFocused)
            // macOS 14.0+ (Sequoia is 15.0)
            .onKeyPress(phases: .down) { press in
                if isRecording {
                    // エスケープキーでキャンセル
                    if press.key == .escape {
                        isRecording = false
                        isFocused = false
                        return .handled
                    }
                    
                    // 文字入力を取得
                    let char = press.key.character
                    self.key = String(char)
                    self.modifiers = convertModifiersToInt(press.modifiers)
                    isRecording = false
                    isFocused = false
                    return .handled
                }
                return .ignored
            }
            // フォーカスが外れたら録音終了
            .onChange(of: isFocused) { _, focused in
                if !focused { isRecording = false }
            }
        }
    }
    
    var shortcutDescription: String {
        var text = ""
        let mod = convertIntToModifiers(modifiers)
        if mod.contains(.command) { text += "⌘" }
        if mod.contains(.shift) { text += "⇧" }
        if mod.contains(.option) { text += "⌥" }
        if mod.contains(.control) { text += "⌃" }
        text += key.uppercased()
        return text
    }
    
    // SwiftUI EventModifiers <-> Int
    // Command: 1, Shift: 2, Option: 4, Control: 8 (Simplified bitmask)
    // Note: This needs to match the storage logic.
    // NSEvent.ModifierFlags values are large. Let's use simple custom mapping for AppStorage.
    // Command=1<<20, but let's map:
    // Cmd:1, Shift:2, Opt:4, Ctrl:8
    
    func convertModifiersToInt(_ mods: EventModifiers) -> Int {
        var val = 0
        // NSEvent compatible values for easier "Command" default (1048576)
        // No, let's stick to NSEvent raw values if possible, or simple mapping.
        // User requested "Command" as default.
        // Let's use NSEvent values if possible or map.
        // Let's use simple:
        if mods.contains(.command) { val += 1 }
        if mods.contains(.shift) { val += 2 }
        if mods.contains(.option) { val += 4 }
        if mods.contains(.control) { val += 8 }
        return val
    }
    
    func convertIntToModifiers(_ val: Int) -> EventModifiers {
        // Handle legacy/NSEvent values if existing app, otherwise simple map.
        // My defaults above were NSEvent values (1048576).
        // Let's normalize to simple values for the new recorder.
        // If val > 100, it's likely NSEvent value.
        
        var mods: EventModifiers = []
        
        if val > 1000 {
            // NSEvent mapping (approximate)
            if (val & 1048576) != 0 { mods.insert(.command) } // cmd
            if (val & 131072) != 0 { mods.insert(.shift) }    // shift
            if (val & 524288) != 0 { mods.insert(.option) }   // opt
            if (val & 262144) != 0 { mods.insert(.control) }  // ctrl
        } else {
            // Simple mapping
            if (val & 1) != 0 { mods.insert(.command) }
            if (val & 2) != 0 { mods.insert(.shift) }
            if (val & 4) != 0 { mods.insert(.option) }
            if (val & 8) != 0 { mods.insert(.control) }
        }
        return mods
    }
}

