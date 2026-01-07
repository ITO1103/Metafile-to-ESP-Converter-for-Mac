# Metafile to EPS Converter for Mac

メタファイルをEPS（Encapsulated PostScript）およびPDFファイルに変換するMacアプリケーション

## 機能

- **EPS変換**: TIFF，PNG，JPEGをEPS形式に変換（外部依存なし）
- **PDF変換**: 画像をPDF形式に変換
- **コピー/ペースト**: クリップボード経由での画像の操作
- **プレビュー表示**: 読み込んだ画像をプレビューで確認
- **複数形式保存**: TIFF, PNG, JPEG形式での保存

## 必要要件

### システム要件
- macOS Sequoia(15.0) 以降
- Xcode 15.0以降（ソースからビルドする場合）

### 依存関係

**外部依存なし** - すべての変換機能はmacOSのネイティブAPIを使用して実装されています．

ただし，PDFからベクターEPSへの変換を行いたい場合は，別途`pdftops`（Popplerの一部）などのツールを使用することを推奨します．

#### オプション：ベクターEPS変換ツールのインストール
以下のコマンドでPopplerをインストールできます．
```bash
brew install poppler
```
（インストール後，PDFとして出力したファイルを `pdftops -eps input.pdf output.eps` で変換することで，完全なベクターEPSが得られます）

## インストール方法

1. このリポジトリをクローンまたはダウンロード
2. Xcodeでプロジェクトを開く
3. ビルドして実行

## 使用方法

1. **変換ソースの読み込み**
    - `Open Metafile`ボタンからソースの読み込み
    - ペースト `Command ⌘` + `V`で読み込み

2. **ファイルの書き出し**
    - `Export EPS`ボタンでEPS形式で出力
    - `Export PDF`ボタンでPDF形式で出力
    - `Save Metafile`ボタンでTIFF/PNG/JPEG形式で出力

## サポートされているファイル形式

### 入力形式
- TIFF (.tiff)
- PNG (.png)
- JPEG (.jpg, .jpeg)

### 出力形式
- EPS (.eps) - ネイティブ実装
- PDF (.pdf) - ネイティブ実装
- TIFF (.tiff)
- PNG (.png)
- JPEG (.jpg, .jpeg)

## 技術詳細

### EPS生成について

EPS出力はPostScript Level 2の`colorimage`演算子を使用して実装されています．
画像データはASCII Hex形式でエンコードされ，RGB 24bitカラーのラスター画像として出力されます．
（本アプリケーション単体ではベクターEPSの出力は行いません．ベクターデータが必要な場合はPDFエクスポートを推奨します）

### PDF生成について

PDF出力はmacOSのCore Graphics (Quartz 2D) を使用して実装されています．
Officeソフト等からクリップボード経由でコピーされたベクター図形は，そのままベクターデータとして保持され，高品質なPDFとして出力されます．

## ライセンス
このプロジェクトは [MITライセンス](LICENSE) のもとで公開されています．

## 貢献

バグ報告や機能要求は，GitHubのIssuesページからお願いします．

## 開発者

Created by Shunsuke ITO