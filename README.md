# Photo → Telegram Sync

iPhoneの「写真」アプリに新しく追加された写真・動画を、自動的に自分のTelegram Botへ転送するiOSアプリです。
Telegramを「容量無制限の写真バックアップ先」として使う、という発想を自動化しています。

> **配布形態について**: このアプリはApp Storeでは配布していません。ソースコードを公開しているので、
> 自分でXcodeでビルドして使ってください(下記「セットアップ」参照)。

## 何が嬉しいのか

- **Telegramは保存容量に上限がない。** 写真・動画をいくら送っても、iPhone本体やiCloudの空き容量は
  一切減らない。
- **開発者はあなたの写真もパスワードも一切預からない。** サーバーを一切経由せず、端末→Telegram間で
  直接送信する。BotトークンやAPIキーは端末内のKeychainにのみ保存される。
- **原本画質のまま届く。** 写真はTelegramの自動再圧縮を避けるためdocument形式で、動画は
  video形式で送るよう使い分けている。
- **IFTTT/Make等の汎用自動化サービスを経由しない。** 同種の自動化はIFTTT等でも組めるが、それらは
  写真データが一度サードパーティのクラウドを経由する。このアプリは間に他社サーバーを挟まない。

## セットアップ

### 前提

- Xcode(Simulatorでの動作確認・ビルドに使用)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)(`brew install xcodegen`)
- 自分のTelegram Bot(BotFatherで作成、無料。詳細はアプリの初期設定画面に手順を内蔵)

### ビルド

```bash
cd dev
xcodegen generate
open PhotoTelegramSync.xcodeproj
```

Xcodeでビルド・実行し、初回起動時の案内に従ってBotトークンを入力すれば使えます
(chat_idはアプリが自動検出します)。

### テスト

```bash
cd dev
xcodegen generate
xcodebuild test -project PhotoTelegramSync.xcodeproj -scheme PhotoTelegramSync \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

## 技術的な補足

- 写真アクセスは `PhotoKit`。新規写真の検知は前回同期時刻以降の`PHAsset`を`creationDate`で
  絞り込む方式(「同期ボタン」型)。iOSのバックグラウンド実行制約上、撮影と同時の完全自動送信は
  信頼性高くは実現できないため、この方式を採用している。
- 送信はTelegram Bot API(1ファイル50MB上限)。レート制限(HTTP 429/`retry_after`)には
  自動リトライで対応。
- Live Photoの動画クリップ送信は実装済みだが、実機での動作検証はまだ完了していない
  (`dev/CLAUDE.md`参照)。

## ライセンス

[MIT License](LICENSE)
