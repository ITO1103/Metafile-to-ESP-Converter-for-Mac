//
//  ContentView.swift
//  Metafile to ESP Converter for Mac
//
//  Created by Shunsuke ITO on 2025/07/17.
//
//  このファイルはメタファイル（TIFF/PNG/JPEG）をEPS/PDF形式に変換する
//  macOSアプリケーションのメインビューを提供します。
//
//  主な機能:
//  - 画像ファイルの読み込み（Open Metafile）
//  - EPS形式での出力（Export EPS） - ネイティブ実装、外部依存なし
//  - PDF形式での出力（Export PDF）
//  - 各種画像形式での保存（Save Metafile）
//  - クリップボード操作（Copy/Paste）
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Dependency Checker

/// 外部ツールの依存関係をチェックする構造体
struct DependencyChecker {
    /// pdftopsツールのパスを探す
    ///
    /// - Returns: 実行可能なpdftopsのパス、見つからない場合はnil
    static func findPdftops() -> String? {
        let paths = [
            "/opt/homebrew/bin/pdftops",  // Apple Silicon Homebrew
            "/usr/local/bin/pdftops",     // Intel Homebrew
            "/usr/bin/pdftops"            // Standard (rare)
        ]
        
        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        return nil
    }
}

// MARK: - Button Styles

/// 正方形カスタムボタンスタイル
///
/// アプリケーション内のすべてのアクションボタンに適用される統一されたスタイル。
/// 押下時に0.95倍にスケールするアニメーション効果を持つ。
///
/// - Parameter color: ボタンの背景色
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
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Content View

/// アプリケーションのメインビュー
///
/// 画像の読み込み、変換、保存のためのUIを提供する。
/// ボタン群とプレビュー表示エリアで構成される。
struct ContentView: View {
    // MARK: - State Properties
    
    /// 現在読み込まれている画像（プレビュー表示用）
    /// nilの場合はプレースホルダーテキストを表示
    @State private var metafileImage: NSImage? = nil
    
    /// クリップボードから取得したPDFデータ（ベクター品質保持用）
    /// nilの場合はmetafileImageからPDFを生成する
    @State private var pdfData: Data? = nil
    
    /// 読み込んだデータのソースタイプ
    @State private var sourceType: SourceType = .none
    
    /// アラートに表示するエラーメッセージ
    @State private var alertMessage: String? = nil
    
    /// アラートの表示状態
    @State private var showAlert: Bool = false
    
    /// Poppler欠落時の警告アラート表示状態
    @State private var showPopplerAlert: Bool = false
    
    /// プレビューの背景色設定（UserDefaultsから読み込み）
    @AppStorage("previewBackgroundColor") private var previewBackgroundColor: String = "white"
    
    /// 設定に基づいた背景色を返す
    private var currentPreviewColor: Color {
        switch previewBackgroundColor {
        case "gray": return Color.gray.opacity(0.1)
        case "clear": return Color.clear
        default: return Color.white
        }
    }
    
    // MARK: - Shortcut Settings
    @AppStorage("shortcut_paste_key") private var pasteKey: String = "v"
    @AppStorage("shortcut_paste_mod") private var pasteModifiers: Int = 1048576
    
    @AppStorage("shortcut_copy_key") private var copyKey: String = "c"
    @AppStorage("shortcut_copy_mod") private var copyModifiers: Int = 1048576
    
    @AppStorage("shortcut_open_key") private var openKey: String = "o"
    @AppStorage("shortcut_open_mod") private var openModifiers: Int = 1048576
    
    @AppStorage("shortcut_save_key") private var saveKey: String = "s"
    @AppStorage("shortcut_save_mod") private var saveModifiers: Int = 1048576
    
    @AppStorage("shortcut_export_pdf_key") private var exportPDFKey: String = "e"
    @AppStorage("shortcut_export_pdf_mod") private var exportPDFModifiers: Int = 1048576
    
    @AppStorage("shortcut_export_eps_key") private var exportEPSKey: String = "p"
    @AppStorage("shortcut_export_eps_mod") private var exportEPSModifiers: Int = 1179648
    
    private func getModifier(_ val: Int) -> EventModifiers {
        var mods: EventModifiers = []
        if val > 1000 { // Legacy/NSEvent
            if (val & 1048576) != 0 { mods.insert(.command) }
            if (val & 131072) != 0 { mods.insert(.shift) }
            if (val & 524288) != 0 { mods.insert(.option) }
            if (val & 262144) != 0 { mods.insert(.control) }
        } else { // Simple map
            if (val & 1) != 0 { mods.insert(.command) }
            if (val & 2) != 0 { mods.insert(.shift) }
            if (val & 4) != 0 { mods.insert(.option) }
            if (val & 8) != 0 { mods.insert(.control) }
        }
        return mods
    }
    
    private func getKey(_ str: String) -> KeyEquivalent {
        KeyEquivalent(str.first ?? " ")
    }

    /// データのソースタイプを表す列挙型
    enum SourceType {
        case none       // データなし
        case pdf        // PDFデータあり（ベクター品質）
        case raster     // ラスター画像のみ
        
        var description: String {
            switch self {
            case .none: return ""
            case .pdf: return "📐 Vector (PDF)"
            case .raster: return "🖼 Raster"
            }
        }
    }

    // MARK: - Body
    
    var body: some View {
        VStack {
            // ... (省略: ボタン群) ...
            VStack(spacing: 10) {
                // 上段：ファイル操作ボタン
                HStack {
                    Button("Open Metafile") {
                        openMetafile()
                    }
                    .buttonStyle(SquareButtonStyle(color: .blue))
                    .keyboardShortcut(getKey(openKey), modifiers: getModifier(openModifiers))

                    Button("Export EPS") {
                        exportEPS()
                    }
                    .buttonStyle(SquareButtonStyle(color: .green))
                    .keyboardShortcut(getKey(exportEPSKey), modifiers: getModifier(exportEPSModifiers))

                    Button("Export PDF") {
                        exportPDF()
                    }
                    .buttonStyle(SquareButtonStyle(color: .teal))
                    .keyboardShortcut(getKey(exportPDFKey), modifiers: getModifier(exportPDFModifiers))

                    Button("Save Metafile") {
                        saveMetafile()
                    }
                    .buttonStyle(SquareButtonStyle(color: .orange))
                    .keyboardShortcut(getKey(saveKey), modifiers: getModifier(saveModifiers))
                }

                // 下段：クリップボード操作ボタン
                HStack {
                    Button("Copy") {
                        copyMetafile()
                    }
                    .buttonStyle(SquareButtonStyle(color: .purple))
                    .keyboardShortcut(getKey(copyKey), modifiers: getModifier(copyModifiers))

                    Button("Paste") {
                        pasteMetafile()
                    }
                    .buttonStyle(SquareButtonStyle(color: .red))
                    .keyboardShortcut(getKey(pasteKey), modifiers: getModifier(pasteModifiers))
                }
            }
            .padding()

            Spacer()

            // プレビュー表示エリア
            VStack {
                if let image = metafileImage {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 400, maxHeight: 400)
                        .background(currentPreviewColor)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                        .shadow(radius: 5)
                } else {
                    Text("Paste a metafile to display here")
                        .foregroundColor(.gray)
                        .frame(maxWidth: 400, maxHeight: 400)
                        .background(currentPreviewColor)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                }
                
                // ソースタイプ表示
                if sourceType != .none {
                    Text(sourceType.description)
                        .font(.caption)
                        .foregroundColor(sourceType == .pdf ? .green : .orange)
                        .padding(.top, 4)
                }
            }

            Spacer()
        }
        .padding()
        // ウィンドウサイズの制約と初期サイズ設定
        .frame(minWidth: 480, idealWidth: 500, minHeight: 650, idealHeight: 700)
        // Poppler警告アラート
        .alert("Poppler (pdftops) が見つかりません", isPresented: $showPopplerAlert) {
            Button("ラスター形式で出力", role: .none) {
                saveEPS(forceRaster: true)
            }
            Button("キャンセル", role: .cancel) { }
        } message: {
            Text("ベクターEPSを出力するにはPopplerが必要です。\nラスター形式（画像）として出力しますか？\n\n(インストール: brew install poppler)")
        }
        // エラーアラート
        .alert("エラー", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage ?? "不明なエラーが発生しました")
        }
    }
    
    // MARK: - Error Handling

    /// 統一されたエラー表示
    ///
    /// アプリケーション内のすべてのエラーはこのメソッドを通じてユーザーに通知される。
    /// SwiftUIのアラートシステムを使用してモーダルダイアログを表示する。
    ///
    /// - Parameter message: ユーザーに表示するエラーメッセージ
    private func showErrorAlert(_ message: String) {
        alertMessage = message
        showAlert = true
    }

    // MARK: - Supported File Types

    /// サポートされている画像ファイル形式
    ///
    /// 入力として受け付ける画像形式のリスト。
    /// これらの形式はNSImageによってネイティブにサポートされている。
    private var supportedImageTypes: [UTType] {
        [.tiff, .png, .jpeg]
    }

    // MARK: - File Open Operations

    /// 画像ファイルを開く
    ///
    /// ファイル選択ダイアログを表示し、選択された画像をプレビューに読み込む。
    /// 対応形式: TIFF, PNG, JPEG
    ///
    /// - Note: 読み込みに失敗した場合はエラーアラートを表示
    private func openMetafile() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = supportedImageTypes
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.message = "変換する画像ファイルを選択してください"
        
        openPanel.begin { result in
            if result == .OK, let url = openPanel.url {
                if let image = NSImage(contentsOf: url) {
                    metafileImage = image
                } else {
                    showErrorAlert("ファイルの読み込みに失敗しました: \(url.lastPathComponent)")
                }
            }
        }
    }

    // MARK: - EPS Export (Native Implementation)
    
    /// EPS形式でエクスポート
    ///
    /// 現在の画像をEPS形式で保存する。
    /// PDFデータ（ベクター）を利用可能な場合は、`pdftops`ツールを使用してベクターEPSへの変換を試みる。
    /// ツールがない場合やラスター画像の場合は、ネイティブな方法でビットマップEPSを生成する。
    ///
    /// - Note: `pdftops`はHomebrew等でインストール可能（`brew install poppler`）
    private func exportEPS() {
        guard metafileImage != nil else {
            showErrorAlert("変換する画像がありません")
            return
        }
        
        // ベクターソースがあるがツールがない場合、警告
        if pdfData != nil && DependencyChecker.findPdftops() == nil {
            showPopplerAlert = true
        } else {
            saveEPS(forceRaster: false)
        }
    }
    
    /// EPS保存処理を実行
    private func saveEPS(forceRaster: Bool) {
        guard let image = metafileImage else { return }
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [UTType(filenameExtension: "eps")!]
        savePanel.nameFieldStringValue = "output.eps"
        savePanel.message = "EPSファイルの保存先を選択してください"
        
        savePanel.begin { result in
            if result == .OK, let saveURL = savePanel.url {
                do {
                    // ベクターデータ利用可能、かつpdftopsツールがある、かつ強制ラスターでない場合
                    if !forceRaster, let pdfData = pdfData, let pdftopsPath = DependencyChecker.findPdftops() {
                        if let epsData = EPSGenerator.convertPDFToEPS(pdfData, toolURL: URL(fileURLWithPath: pdftopsPath)) {
                            try epsData.write(to: saveURL)
                            return
                        }
                    }
                    
                    // フォールバック：ラスター画像からEPS生成
                    if let epsData = EPSGenerator.generate(from: image) {
                        try epsData.write(to: saveURL)
                    } else {
                        showErrorAlert("EPS生成に失敗しました")
                    }
                } catch {
                    showErrorAlert("EPSファイルの保存に失敗しました: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - PDF Export
    
    /// PDF形式でエクスポート
    ///
    /// 現在の画像をPDF形式で保存する。
    /// クリップボードから取得したベクターPDFがある場合は、それをそのまま保存する。
    /// そうでない場合は、NSImageから高品質なPDFを生成する。
    private func exportPDF() {
        // ベクターPDFデータがある場合はそれを優先
        if let pdfData = pdfData {
            savePDFData(pdfData)
            return
        }
        
        guard let image = metafileImage else {
            showErrorAlert("変換する画像がありません")
            return
        }

        // 画像からPDF生成
        guard let generatedData = PDFGenerator.generate(from: image) else {
            showErrorAlert("PDF生成に失敗しました")
            return
        }

        savePDFData(generatedData)
    }
    
    /// PDFデータを保存するヘルパーメソッド
    private func savePDFData(_ data: Data) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.pdf]
        savePanel.nameFieldStringValue = "output.pdf"
        savePanel.message = "PDFファイルの保存先を選択してください"
        
        savePanel.begin { result in
            if result == .OK, let saveURL = savePanel.url {
                do {
                    try data.write(to: saveURL)
                } catch {
                    showErrorAlert("PDFファイルの保存に失敗しました: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Image Save Operations

    /// 画像を指定形式で保存
    ///
    /// 現在の画像をTIFF, PNG, またはJPEG形式で保存する。
    /// ファイル拡張子に基づいて適切な形式で出力される。
    ///
    /// - Note: 選択した拡張子と実際の出力形式は一致することが保証される
    private func saveMetafile() {
        guard let image = metafileImage else {
            showErrorAlert("保存する画像がありません")
            return
        }

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = supportedImageTypes
        savePanel.message = "画像の保存先を選択してください"
        
        savePanel.begin { result in
            if result == .OK, let url = savePanel.url {
                do {
                    let imageData = try createImageData(from: image, for: url.pathExtension)
                    try imageData.write(to: url)
                } catch {
                    showErrorAlert("画像の保存に失敗しました: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// 指定された拡張子に対応する形式で画像データを作成
    ///
    /// NSImageから指定されたファイル形式のDataを生成する。
    /// 内部でNSBitmapImageRepを使用して形式変換を行う。
    ///
    /// - Parameters:
    ///   - image: 変換元のNSImage
    ///   - pathExtension: 出力ファイルの拡張子（png, jpg, tiff等）
    /// - Returns: 指定形式でエンコードされた画像データ
    /// - Throws: 画像データが無効な場合、または変換に失敗した場合
    private func createImageData(from image: NSImage, for pathExtension: String) throws -> Data {
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData) else {
            throw ImageConversionError.invalidImageData
        }
        
        // 拡張子からファイル形式を決定
        let fileType: NSBitmapImageRep.FileType
        switch pathExtension.lowercased() {
        case "png":
            fileType = .png
        case "jpg", "jpeg":
            fileType = .jpeg
        case "tiff", "tif":
            fileType = .tiff
        default:
            fileType = .tiff  // デフォルトはTIFF
        }
        
        // JPEG形式の場合は品質を設定
        var properties: [NSBitmapImageRep.PropertyKey: Any] = [:]
        if fileType == .jpeg {
            properties[.compressionFactor] = 0.9  // 90%品質
        }
        
        guard let data = bitmapRep.representation(using: fileType, properties: properties) else {
            throw ImageConversionError.conversionFailed
        }
        
        return data
    }

    // MARK: - Clipboard Operations

    /// 画像をクリップボードにコピー
    ///
    /// 現在の画像をTIFF形式でシステムクリップボードにコピーする。
    /// 他のアプリケーションにペーストして使用できる。
    private func copyMetafile() {
        guard let image = metafileImage else {
            showErrorAlert("コピーする画像がありません")
            return
        }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(image.tiffRepresentation, forType: .tiff)
    }

    /// クリップボードから画像をペースト
    ///
    /// システムクリップボードから画像を読み込み、プレビューに表示する。
    /// Vector（PDF）データを優先的に取得する。
    ///
    /// 優先順位:
    /// 1. PDFデータ（Office等のベクター図形）
    /// 2. ファイルURL（Finderからのコピー）
    /// 3. TIFF/PNG/JPEG形式データ
    private func pasteMetafile() {
        let pasteboard = NSPasteboard.general
        
        // 1. PDFデータを確認（ベクター優先）
        // .pdfタイプを確認
        if let data = pasteboard.data(forType: .pdf) {
            // PDFデータからNSImageを作成（プレビュー用）
            if let image = NSImage(data: data) {
                print("PDF data found in clipboard. Size: \(data.count) bytes")
                metafileImage = image
                pdfData = data
                sourceType = .pdf
                return
            }
        }
        
        // 2. クリップボードからファイルURLを取得（Finderからのコピー対応）
        if let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let fileURL = fileURLs.first {
            if let image = NSImage(contentsOf: fileURL) {
                metafileImage = image
                
                // ファイルがPDFの場合はPDFデータを保持
                if fileURL.pathExtension.lowercased() == "pdf",
                   let data = try? Data(contentsOf: fileURL) {
                    pdfData = data
                    sourceType = .pdf
                } else {
                    pdfData = nil
                    sourceType = .raster
                }
                return
            }
        }
        
        // 3. 各種画像形式のデータを試行
        let imageTypes: [NSPasteboard.PasteboardType] = [.tiff, .png]
        for imageType in imageTypes {
            if let data = pasteboard.data(forType: imageType), 
               let image = NSImage(data: data) {
                metafileImage = image
                pdfData = nil
                sourceType = .raster
                return
            }
        }
        
        // 4. JPEG形式を個別にチェック
        if let data = pasteboard.data(forType: NSPasteboard.PasteboardType("public.jpeg")),
           let image = NSImage(data: data) {
            metafileImage = image
            pdfData = nil
            sourceType = .raster
            return
        }
        
        // 何も見つからない場合
        showErrorAlert("クリップボードにサポートされている画像が見つかりません\n(PDF, TIFF, PNG, JPEG)")
    }
}

// MARK: - EPS Generator

/// EPSファイル生成クラス
///
/// NSImageからEPS (Encapsulated PostScript) 形式のデータを生成する。
/// Level 2 PostScriptの仕様に準拠し、24ビットRGBカラー画像を出力する。
///
/// ## 実装詳細
/// - ヘッダー: PS-Adobe-3.0 EPSF-3.0準拠
/// - 画像データ: ASCII Hex形式でエンコード
/// - カラーモデル: RGB (24bit)
///
/// ## 使用例
/// ```swift
/// if let epsData = EPSGenerator.generate(from: nsImage) {
///     try epsData.write(to: fileURL)
/// }
/// ```
enum EPSGenerator {
    
    /// PDFデータからベクターEPSを生成（pdftopsを使用）
    ///
    /// - Parameters:
    ///   - pdfData: 変換元のPDFデータ
    ///   - toolURL: pdftopsツールのファイルURL
    /// - Returns: EPSフォーマットのData、失敗時はnil
    static func convertPDFToEPS(_ pdfData: Data, toolURL: URL) -> Data? {
        // 透明背景によるグレー化を防ぐため、白背景を合成したPDFを一時作成
        guard let processedPDF = addWhiteBackground(to: pdfData) else {
            return nil
        }
        
        let tempDir = FileManager.default.temporaryDirectory
        let uuid = UUID().uuidString
        let pdfURL = tempDir.appendingPathComponent("\(uuid).pdf")
        let epsURL = tempDir.appendingPathComponent("\(uuid).eps")
        
        do {
            try processedPDF.write(to: pdfURL)
            
            let process = Process()
            process.executableURL = toolURL
            process.arguments = ["-eps", "-level2", pdfURL.path, epsURL.path]
            
            try process.run()
            process.waitUntilExit()
            
            guard process.terminationStatus == 0 else {
                try? FileManager.default.removeItem(at: pdfURL)
                return nil
            }
            
            let epsData = try Data(contentsOf: epsURL)
            
            try? FileManager.default.removeItem(at: pdfURL)
            try? FileManager.default.removeItem(at: epsURL)
            
            return epsData
        } catch {
            print("pdftops conversion failed: \(error)")
            try? FileManager.default.removeItem(at: pdfURL)
            try? FileManager.default.removeItem(at: epsURL)
            return nil
        }
    }
    
    /// PDFに白背景を追加する（ベクター品質を維持）
    ///
    /// - Parameter pdfData: 元のPDFデータ
    /// - Returns: 白背景が追加されたPDFデータ
    private static func addWhiteBackground(to pdfData: Data) -> Data? {
        guard let dataProvider = CGDataProvider(data: pdfData as CFData),
              let document = CGPDFDocument(dataProvider),
              let page = document.page(at: 1) else {
            return nil
        }
        
        var mediaBox = page.getBoxRect(.mediaBox)
        let newPDFData = NSMutableData()
        
        guard let consumer = CGDataConsumer(data: newPDFData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            return nil
        }
        
        context.beginPDFPage(nil)
        
        // 白で塗りつぶし
        context.setFillColor(NSColor.white.cgColor)
        context.fill(mediaBox)
        
        // 元のPDFページを描画（ベクター維持）
        context.drawPDFPage(page)
        
        context.endPDFPage()
        context.closePDF()
        
        return newPDFData as Data
    }

    /// NSImageからEPSデータを生成
    ///
    /// - Parameter image: 変換元の画像
    /// - Returns: EPSフォーマットのData、失敗時はnil
    static func generate(from image: NSImage) -> Data? {
        // 画像からビットマップ表現を取得
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        
        let width = bitmapRep.pixelsWide
        let height = bitmapRep.pixelsHigh
        
        // EPSヘッダーを構築
        var epsContent = buildEPSHeader(width: width, height: height)
        
        // PostScript画像描画コードを追加
        epsContent += buildImageOperator(width: width, height: height)
        
        // ピクセルデータをHex形式で追加
        epsContent += extractPixelDataAsHex(from: bitmapRep)
        
        // フッターを追加
        epsContent += "\nshowpage\n%%EOF\n"
        
        return epsContent.data(using: .ascii)
    }
    
    /// EPSヘッダーを構築
    ///
    /// PS-Adobe-3.0 EPSF-3.0準拠のヘッダーコメントを生成する。
    /// BoundingBox、作成日時、アプリケーション情報を含む。
    ///
    /// - Parameters:
    ///   - width: 画像の幅（ピクセル）
    ///   - height: 画像の高さ（ピクセル）
    /// - Returns: EPSヘッダー文字列
    private static func buildEPSHeader(width: Int, height: Int) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let creationDate = dateFormatter.string(from: Date())
        
        return """
        %!PS-Adobe-3.0 EPSF-3.0
        %%BoundingBox: 0 0 \(width) \(height)
        %%HiResBoundingBox: 0.0 0.0 \(Double(width)) \(Double(height))
        %%Creator: Metafile to EPS Converter for Mac
        %%CreationDate: \(creationDate)
        %%LanguageLevel: 2
        %%EndComments
        %%BeginProlog
        %%EndProlog
        %%Page: 1 1
        
        """
    }
    
    /// PostScript画像描画演算子を構築
    ///
    /// Level 2 PostScriptのcolorimage演算子を使用した
    /// 画像描画コードを生成する。
    ///
    /// - Parameters:
    ///   - width: 画像の幅
    ///   - height: 画像の高さ
    /// - Returns: PostScript画像演算子コード
    private static func buildImageOperator(width: Int, height: Int) -> String {
        // gsave/grestore で状態を保存
        // translate で座標系を設定
        // scale で画像サイズを設定
        // colorimage で RGB画像を描画
        return """
        gsave
        0 0 translate
        \(width) \(height) scale
        
        /picstr \(width * 3) string def
        \(width) \(height) 8
        [\(width) 0 0 -\(height) 0 \(height)]
        {currentfile picstr readhexstring pop}
        false 3
        colorimage
        
        """
    }
    
    /// ビットマップからピクセルデータをHex形式で抽出
    ///
    /// 各ピクセルのRGB値を2桁の16進数文字列に変換する。
    /// 透明度（アルファ）がある場合は白背景に合成する。
    ///
    /// ## 実装方針
    /// NSBitmapImageRepのピクセルフォーマットは様々な可能性があるため、
    /// `colorAt(x:y:)`を使用して確実に色を取得し、アルファを白背景に合成する。
    /// パフォーマンスより正確性を優先。
    ///
    /// - Parameter bitmapRep: 変換元のビットマップ表現
    /// - Returns: Hex形式のピクセルデータ文字列
    private static func extractPixelDataAsHex(from bitmapRep: NSBitmapImageRep) -> String {
        let width = bitmapRep.pixelsWide
        let height = bitmapRep.pixelsHigh
        
        // 容量を事前確保して高速化（各ピクセル6文字 + 改行）
        var hexChars: [UInt8] = []
        hexChars.reserveCapacity(width * height * 6 + height)
        
        let hexTable: [UInt8] = Array("0123456789ABCDEF".utf8)
        
        // 上から下へスキャン
        for y in 0..<height {
            for x in 0..<width {
                // ピクセルの色を取得
                let (r, g, b) = getPixelRGB(from: bitmapRep, x: x, y: y)
                
                // Hex変換
                hexChars.append(hexTable[Int(r >> 4)])
                hexChars.append(hexTable[Int(r & 0x0F)])
                hexChars.append(hexTable[Int(g >> 4)])
                hexChars.append(hexTable[Int(g & 0x0F)])
                hexChars.append(hexTable[Int(b >> 4)])
                hexChars.append(hexTable[Int(b & 0x0F)])
            }
            
            // 各行末で改行（PostScript互換性のため）
            hexChars.append(UInt8(ascii: "\n"))
        }
        
        return String(bytes: hexChars, encoding: .ascii) ?? ""
    }
    
    /// 指定座標のピクセルからRGB値を取得
    ///
    /// アルファチャンネルがある場合は白背景に合成する。
    /// 様々なピクセルフォーマット（RGB, RGBA, グレースケール等）に対応。
    ///
    /// - Parameters:
    ///   - bitmapRep: ビットマップ表現
    ///   - x: X座標
    ///   - y: Y座標
    /// - Returns: RGB値のタプル（各成分0-255）
    private static func getPixelRGB(from bitmapRep: NSBitmapImageRep, x: Int, y: Int) -> (UInt8, UInt8, UInt8) {
        // colorAt を使用して確実に色を取得
        guard let color = bitmapRep.colorAt(x: x, y: y) else {
            // 取得できない場合は白を返す
            return (255, 255, 255)
        }
        
        // sRGB色空間に変換（異なる色空間の場合に対応）
        guard let rgbColor = color.usingColorSpace(.sRGB) else {
            // 変換できない場合はそのまま試す
            let r = UInt8(clamping: Int(color.redComponent * 255))
            let g = UInt8(clamping: Int(color.greenComponent * 255))
            let b = UInt8(clamping: Int(color.blueComponent * 255))
            return (r, g, b)
        }
        
        // アルファ値を取得
        let alpha = rgbColor.alphaComponent
        
        // RGB成分を取得
        var r = rgbColor.redComponent
        var g = rgbColor.greenComponent
        var b = rgbColor.blueComponent
        
        // アルファ合成（白背景）
        // 公式: result = foreground * alpha + background * (1 - alpha)
        // 白背景 = 1.0 なので: result = foreground * alpha + (1 - alpha)
        if alpha < 1.0 {
            let oneMinusAlpha = 1.0 - alpha
            r = r * alpha + oneMinusAlpha
            g = g * alpha + oneMinusAlpha
            b = b * alpha + oneMinusAlpha
        }
        
        // 0-255範囲にクランプして変換
        let rByte = UInt8(clamping: Int(r * 255.0 + 0.5))
        let gByte = UInt8(clamping: Int(g * 255.0 + 0.5))
        let bByte = UInt8(clamping: Int(b * 255.0 + 0.5))
        
        return (rByte, gByte, bByte)
    }
}

// MARK: - PDF Generator

/// PDFファイル生成クラス
///
/// NSImageからPDF形式のデータを生成する。
/// NSImageを直接描画することで、可能な限り高品質を維持する。
///
/// ## 使用例
/// ```swift
/// if let pdfData = PDFGenerator.generate(from: nsImage) {
///     try pdfData.write(to: fileURL)
/// }
/// ```
enum PDFGenerator {
    
    /// NSImageからPDFデータを生成
    ///
    /// NSImageを直接PDFコンテキストに描画することで、
    /// ベクター表現がある場合はそれを保持し、高品質なPDFを生成する。
    ///
    /// - Parameter image: 変換元の画像
    /// - Returns: PDFフォーマットのData、失敗時はnil
    static func generate(from image: NSImage) -> Data? {
        // 画像サイズを取得（ポイント単位）
        let imageSize = image.size
        
        guard imageSize.width > 0 && imageSize.height > 0 else {
            return nil
        }
        
        // PDFドキュメント用のデータを作成
        let pdfData = NSMutableData()
        
        // PDFコンテキストを作成
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData) else {
            return nil
        }
        
        var mediaBox = CGRect(origin: .zero, size: imageSize)
        
        // PDFメタデータを設定
        let auxiliaryInfo: [CFString: Any] = [
            kCGPDFContextCreator: "Metafile to EPS Converter for Mac" as CFString,
            kCGPDFContextTitle: "Converted Image" as CFString
        ]
        
        guard let pdfContext = CGContext(consumer: consumer, mediaBox: &mediaBox, auxiliaryInfo as CFDictionary) else {
            return nil
        }
        
        // PDFページを開始
        pdfContext.beginPDFPage(nil)
        
        // NSGraphicsContextを使用してNSImageを直接描画
        // これにより、NSImageの内部表現（ベクターまたは高解像度ラスター）が保持される
        let nsContext = NSGraphicsContext(cgContext: pdfContext, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsContext
        
        // NSImageを描画
        // draw(in:from:operation:fraction:)を使用してフル品質で描画
        image.draw(
            in: NSRect(origin: .zero, size: imageSize),
            from: .zero,  // ソース全体から
            operation: .copy,
            fraction: 1.0  // フル不透明度
        )
        
        NSGraphicsContext.restoreGraphicsState()
        
        // PDFページを終了
        pdfContext.endPDFPage()
        pdfContext.closePDF()
        
        return pdfData as Data
    }
}

// MARK: - Errors

/// 画像変換エラー
///
/// 画像形式の変換処理中に発生する可能性のあるエラーを定義する。
enum ImageConversionError: LocalizedError {
    /// 画像データが無効または読み取れない
    case invalidImageData
    /// 指定された形式への変換に失敗
    case conversionFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidImageData:
            return "画像データが無効です"
        case .conversionFailed:
            return "画像形式の変換に失敗しました"
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
