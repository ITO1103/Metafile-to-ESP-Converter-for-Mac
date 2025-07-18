# Metafile to EPS Converter for Mac

メタファイルをEPS（Encapsulated PostScript）ファイルに変換するMacアプリケーション

## 機能

- **EPS変換**: Metafile，TIFF，PNG，JPEGをEPS形式に変換
- **コピー/ペースト**: クリップボード経由での画像の操作
- **プレビュー表示**: 読み込んだ画像をプレビューで確認

## 必要要件

### システム要件
- macOS Sequoia(14.0) 以降
- Xcode 15.0以降（ソースからビルドする場合）

### 依存関係

このアプリケーションは**ImageMagick**を使用してEPS変換を行います．

#### ImageMagickのインストール
https://formulae.brew.sh/formula/imagemagick

Homebrewを使用してImageMagickをインストールする場合は，以下のコマンドをターミナルで実行：

```bash
brew install imagemagick
```

ImageMagickがインストールされていない場合，EPS変換機能は使用できません．

## インストール方法

1. このリポジトリをクローンまたはダウンロード
2. ImageMagickをインストール（上記参照）
3. Xcodeでプロジェクトを開く
4. ビルドして実行

## 使用方法

1. **変換ソースの読み込み**
    - `Open Metafile`ボタンからソースの読み込み
    - ペースト `Command ⌘` + `V`で読み込み

2. **ファイルの書き出し**
    - `Export EPS`ボタンでEPS形式で出力
    - `Save Metafile`ボタンでTIFF形式で出力

## サポートされているファイル形式

### 入力形式
- Metafile 
- TIFF (.tiff)
- PNG (.png)
- JPEG (.jpg, .jpeg)

### 出力形式
- EPS (.eps) - ImageMagick経由
- TIFF (.tiff)
- PNG (.png)
- JPEG (.jpg, .jpeg)

## トラブルシューティング

### ImageMagickが見つからない

"ImageMagickが見つかりません"というエラーが表示される場合：

1. ImageMagickがインストールされているか確認：
   ```bash
   which magick
   ```

2. インストールされていない場合：
   ```bash
   brew install imagemagick
   ```

3. Homebrewがインストールされていない場合は，[Homebrew公式サイト](https://brew.sh/ja/)からインストールしてください

## ライセンス
このプロジェクトは [MITライセンス](LICENSE) のもとで公開されています．

## 貢献

バグ報告や機能要求は，GitHubのIssuesページからお願いします．

## 開発者

Created by Shunsuke ITO