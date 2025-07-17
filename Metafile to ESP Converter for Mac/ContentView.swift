//
//  ContentView.swift
//  Metafile to ESP Converter for Mac
//
//  Created by Shunsuke ITO on 2025/07/17.
//

import SwiftUI
import AppKit

struct SquareButtonStyle: ButtonStyle {
    let color: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 100, height: 100)
            .background(color)
            .foregroundColor(.white)
            .cornerRadius(10)
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct ContentView: View {
    @State private var metafileImage: NSImage? = nil

    // エラー表示
    private func showErrorAlert(_ message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = message
        alert.runModal()
    }

    var body: some View {
        VStack {
            HStack {
                Button("Open Metafile") {
                    openMetafile()
                }
                .buttonStyle(SquareButtonStyle(color: .blue))

                Button("Export EPS") {
                    exportEPS()
                }
                .buttonStyle(SquareButtonStyle(color: .green))

                Button("Save Metafile") {
                    saveMetafile()
                }
                .buttonStyle(SquareButtonStyle(color: .orange))

                Button("Copy") {
                    copyMetafile()
                }
                .buttonStyle(SquareButtonStyle(color: .purple))

                Button("Paste") {
                    pasteMetafile()
                }
                .buttonStyle(SquareButtonStyle(color: .red))
            }
            .padding()

            Spacer()

            if let image = metafileImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 400, maxHeight: 400)
            } else {
                Text("Paste a metafile to display here")
                    .foregroundColor(.gray)
            }

            Spacer()
        }
        .padding()
    }

    private func openMetafile() {
        let openPanel = NSOpenPanel()
        openPanel.allowedFileTypes = ["tiff", "png", "jpg", "jpeg"]
        openPanel.begin { result in
            if result == .OK, let url = openPanel.url {
                if let image = NSImage(contentsOf: url) {
                    metafileImage = image
                } else {
                    showErrorAlert("ファイルの読み込みに失敗しました: \(url.path)")
                }
            }
        }
    }

    private func getMagickPath() -> String? {
        let intelPath = "/usr/local/bin/magick"
        let appleSiliconPath = "/opt/homebrew/bin/magick"

        if FileManager.default.fileExists(atPath: appleSiliconPath) {
            return appleSiliconPath
        } else if FileManager.default.fileExists(atPath: intelPath) {
            return intelPath
        } else {
            return nil
        }
    }

    private func exportEPS() {
        guard let image = metafileImage else { return }

        guard let magickPath = getMagickPath() else {
            showErrorAlert("ImageMagickが見つかりません。Homebrewでインストールしてください。")
            return
        }

        guard let tiffData = image.tiffRepresentation else {
            showErrorAlert("TIFFデータの取得に失敗しました。")
            return
        }

        let tempDir = FileManager.default.temporaryDirectory
        let tiffURL = tempDir.appendingPathComponent("input_temp.tiff")
        let epsURL = tempDir.appendingPathComponent("output_temp.eps")

        do {
            try tiffData.write(to: tiffURL)

            let process = Process()
            process.executableURL = URL(fileURLWithPath: magickPath)
            process.arguments = [tiffURL.path, epsURL.path]
            process.environment = [
                "PATH": "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
            ]

            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                let savePanel = NSSavePanel()
                savePanel.allowedFileTypes = ["eps"]
                savePanel.begin { result in
                    if result == .OK, let saveURL = savePanel.url {
                        do {
                            if FileManager.default.fileExists(atPath: saveURL.path) {
                                try FileManager.default.removeItem(at: saveURL)
                            }
                            try FileManager.default.copyItem(at: epsURL, to: saveURL)
                            print("EPSファイルを保存しました: \(saveURL.path)")
                        } catch {
                            print("EPSファイルの保存に失敗: \(error)")
                        }
                    }
                }
            } else {
                print("magickコマンドが失敗しました。終了コード: \(process.terminationStatus)")
            }

        } catch {
            showErrorAlert("EPS変換中のエラー: \(error.localizedDescription)")
        }
    }


    private func saveMetafile() {
        guard let image = metafileImage else { return }

        let savePanel = NSSavePanel()
        savePanel.allowedFileTypes = ["tiff", "png", "jpg", "jpeg"]
        savePanel.begin { result in
            if result == .OK, let url = savePanel.url {
                do {
                    try image.tiffRepresentation?.write(to: url)
                } catch {
                    showErrorAlert("メタファイルの保存に失敗しました: \(error.localizedDescription)")
                }
            }
        }
    }

    private func copyMetafile() {
        guard let image = metafileImage else { return }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(image.tiffRepresentation, forType: .tiff)
    }

    private func pasteMetafile() {
        if let clipboardData = NSPasteboard.general.data(forType: .tiff),
           let image = NSImage(data: clipboardData) {
            metafileImage = image
        } else {
            metafileImage = nil
        }
    }    
}

#Preview {
    ContentView()
}
