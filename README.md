# iPhoneの写真をTelegramへ自動バックアップ(容量無制限・オンデバイス処理)

**iPhoneの「写真」アプリに新しく追加された写真・動画を、自動的に自分のTelegram Botへ転送するiOSアプリ**です。
Telegramには保存容量の上限がないため、iPhone本体やiCloudの空き容量を一切使わずに写真・動画を預け続けられます。
サーバーは一切経由せず、端末からTelegramへ直接送信する設計なので、開発者はあなたの写真もパスワードも見ることができません。

> 配布形態について: このアプリはApp Storeでは配布していません。ソースコードを公開しているので、
> 自分のXcodeでビルドして使ってください(下記「使い方」参照)。

## こんな人におすすめ

- Google Photosの無料枠終了・値上げに疲れている人
- iPhone/iCloudの「ストレージがいっぱいです」通知に悩まされている人
- 既にTelegramを使っていて、乗り換えコストなく写真の保存先にできる人
- 「写真の保存先を、開発者にも第三者にも見られたくない」人

## なぜ作ったのか

以前、自分のGoogle Photos(2万枚以上の写真・動画)を、Pythonスクリプトで丸ごとTelegramへ移行したことがある。
Telegramには保存容量の上限がなく、原本画質のまま預けておける器として優秀だと分かったので、
「じゃあ、これから撮る写真も自動でそこに送ればいいのでは」と思って作ったのがこのアプリ。

Google Photosの無料枠が終わったり、iCloudの容量アラートに毎回課金を迫られたりするたびに感じていた
「クラウドに預けているはずなのに、結局は自分の端末の容量問題として跳ね返ってくる」というストレスを、
なくしたかった。

## できること・強み

- **Telegramは保存容量に上限がない。** 写真・動画をいくら送っても、iPhone本体やiCloudの空き容量は
  一切減らない。
- **開発者はあなたの写真もパスワードも一切預からない。** サーバーを一切経由せず、端末→Telegram間で
  直接送信する。BotトークンやAPIキーは端末内のKeychainにのみ保存される。
- **原本画質のまま届く。** 写真はTelegramの自動再圧縮を避けるためdocument形式で、動画は
  video形式で送るよう使い分けている。
- **IFTTT/Make等の汎用自動化サービスを経由しない。** 同種の自動化はIFTTT等でも組めるが、それらは
  写真データが一度サードパーティのクラウドを経由する。このアプリは間に他社サーバーを挟まない。
- **送信した写真は、普段使っているTelegramでそのまま確認できる。** アプリ内には一覧表示をあえて作って
  いない。自分が設定したBotとのトーク画面を開けば、送信された写真・動画が時系列で並んでいる。

## 使い方

初めてTelegram Botを作る人でも迷わないよう、順を追って説明する。

### 1. 必要なものを揃える

- Xcode(最新版。ビルド・Simulatorでの動作確認に使う)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — `brew install xcodegen`
- Telegramアプリ(まだの場合は[App Store](https://apps.apple.com/app/telegram-messenger/id686449807)から)

### 2. 自分専用のTelegram Botを作る

1. Telegramで `@BotFather`(公式のBot作成係アカウント)を検索して開く
2. `/newbot` と送信
3. Botの表示名を好きに決めて送信(例: `My Photo Sync`)
4. Botのユーザー名を決めて送信。末尾は必ず `bot` で終わる(例: `my_photo_sync_bot`)
5. 成功すると「Use this token to access the HTTP API:」というメッセージと一緒に、
   長いトークン文字列が送られてくる。これを控えておく

### 3. このリポジトリをビルドする

```bash
git clone https://github.com/ryu1616gugu888-beep/photo-telegram-sync.git
cd photo-telegram-sync/dev
xcodegen generate
open PhotoTelegramSync.xcodeproj
```

Xcodeでビルド・実行すると、初期設定画面が表示される。手順2で控えたBotトークンを貼り付け、
Botに1通メッセージを送ってから「chat_idを自動取得」をタップすれば設定完了(curlやターミナル操作は不要)。

### 4. 使う

「今すぐ同期」をタップすると、前回同期以降に追加された写真・動画がTelegramへ送信される。
届いた写真はTelegramの当該Botとのトーク画面でそのまま確認できる。

### テスト

```bash
cd dev
xcodegen generate
xcodebuild test -project PhotoTelegramSync.xcodeproj -scheme PhotoTelegramSync \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

## 技術的な仕組み

- 写真アクセスは `PhotoKit`。新規写真の検知は前回同期時刻以降の`PHAsset`を`creationDate`で
  絞り込む方式(「同期ボタン」型)。iOSのバックグラウンド実行制約上、撮影と同時の完全自動送信は
  信頼性高くは実現できないため、この方式を採用している。
- 送信はTelegram Bot API(1ファイル50MB上限、超過分は送信せずスキップ)。レート制限
  (HTTP 429/`retry_after`)には自動リトライで対応。
- 重複排除は`PHAsset.localIdentifier`を送信済みリストとして永続化。

## 今後・既知の制約

- Live Photoの動画クリップ送信は実装済みだが、実機での動作検証はまだ完了していない
  ([issue #1](https://github.com/ryu1616gugu888-beep/photo-telegram-sync/issues/1))。
- より大きなファイル(2GB/4GB)に対応する個人アカウント(MTProto)方式は将来の拡張候補(未着手)。
- 詳細な設計判断の経緯は `docs/` 以下のドキュメントを参照。

## ライセンス

[MIT License](LICENSE)
