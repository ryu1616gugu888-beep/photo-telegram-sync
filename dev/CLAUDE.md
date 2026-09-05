# CLAUDE.md (dev/ 専用: iOSアプリ開発)

このディレクトリは iPhone写真→Telegram自動転送アプリの実装(Swift/Xcode)を担当する。
ルートの [../CLAUDE.md](../CLAUDE.md) の方針を必ず先に守ること(特にオンデバイス処理・
認証情報非預かりの原則、api_id/api_hash非共有の原則)。技術知見の全文は
[../docs/photo_telegram_ios_app_manual.md](../docs/photo_telegram_ios_app_manual.md) を参照。

## 現在のフェーズ

2026-09-05: 「ユーザー介入は最小限に」という方針(../CLAUDE.md参照)を受け、Step1(ショートカット
プロトタイプ)は飛ばし、直接Xcodeネイティブアプリの実装に着手した。`project.yml`(XcodeGen定義)と
`Sources/PhotoTelegramSync/` 配下にSwiftソース一式(Keychain/SyncStateStore/TelegramClient/
PhotoLibraryManager/OnboardingView/ContentView/App)を書き上げ、`xcodegen generate` で
`.xcodeproj` の生成まで確認済み(コマンドは通った=project.yml・Info.plist設定は正しい)。

**重要な既知の制約: このMacにはXcode本体が未インストール**(Command Line Toolsのみ)。
`xcodebuild`もiOS Simulatorも使えないため、実際のビルド・実機/Simulatorでの動作確認は
**Xcodeのインストール後でないと行えない**。Xcodeのインストールは App Store 経由でユーザーの
Apple ID認証が必要なため、Claude Codeは代行できない(安全ルール上のアカウント認証系の制約)。
→ ユーザーには「App StoreからXcodeをインストールしてほしい」という依頼が必要(数十GBあり時間がかかる)。
Xcodeインストール後にやること: `cd dev && xcodegen generate && open PhotoTelegramSync.xcodeproj`
(または `xcodebuild -scheme PhotoTelegramSync -destination 'platform=iOS Simulator,name=iPhone 16' build`)。

`.xcodeproj` は `project.yml` から再生成可能なので意図的にgitignore対象にしている。
`project.yml`か`Sources/`を変更したら都度 `xcodegen generate` を実行すること。

## Telegram Bot(検証用)

ユーザーが `@unlimited_photo_app_bot` を作成済み。トークンは `dev/.env.local`
(gitignore対象、平文で保存、Botトークンは疑似APIキーでありユーザーアカウント認証情報そのものではない)
に保存している。`scripts/telegram_api_check.sh` でXcodeなしでもBot API疎通・送信フォーマット
(document/video)をcurlベースで検証できる。chat_id取得にはユーザーがBotへ1通メッセージを送る操作が必要
(これも「相手アカウントでの操作」ではなく単なるメッセージ送信なので、都度これくらいの最小操作は
発生し得る)。

## アーキテクチャ要点(元マニュアルの要約、詳細は上記リンク先を参照)

- 写真アクセスは `PhotoKit`(`PHPhotoLibrary`権限)。`PHAsset.creationDate`/`location`/
  `mediaSubtypes`(Live Photo判定)/`localIdentifier`(重複排除キー)を使う。
- Telegramへの送信方式は **Bot API(簡単・50MB上限)** と **個人アカウントMTProto(2GB/4GB・
  api_id/api_hash+電話番号ログインが必要)** の2択。どちらを採用するか、または両方をユーザーに
  選ばせるかは未確定 → オンボーディング画面設計時に決める(推奨: まずBot APIのみでMVPを出し、
  大容量動画のニーズが確認できたらMTProtoを追加)。
- 送信フォーマットの使い分け(実装時に必ず踏襲すること):
  - 写真は原本保持のため **document形式(force_document)** で送る(通常の写真送信は自動再圧縮される)。
  - 動画は逆に **"video"タイプ**で送る(documentだとサムネイルが出ない/再エンコードはされない)。
  - HEICはネイティブに`PHImageManager`でサムネイル生成できるので、旧Pythonスクリプトのような
    `sips`回避策は不要。
  - Live Photoは `PHAsset.mediaSubtypes.contains(.photoLive)` で判定。動画クリップも送るかは
    設定項目にする(デフォルト値は未確定 → オンボーディングで決める)。
- 重複排除は `PHAsset.localIdentifier` を送信済みリストとして永続化(UserDefaults/CoreData)。
- Telegram送信は `FloodWaitError` 相当のレート制限が発生しうるため、指定秒数待ってリトライする
  実装が必須。ファイルサイズ上限超過時の挙動(スキップ/警告)も用意する。
- バックグラウンド実行はiOSの制約で「撮影と同時に完全自動」は信頼性高く実現できない。現実的な
  選択肢は (1)アプリを開いたときに前回同期以降の差分をまとめて送る「同期ボタン」方式、
  (2)iOSショートカットの個人用オートメーション連携、(3)`BGAppRefreshTask`併用。採用方式は
  プロトタイプ検証後に決める。

## 参考にできる既存実装(別セッションで作成済み、Python/Telethon)

ロジックの移植元として、重複排除・キャプション生成・Live Photo判定・EXIFフォールバック・
レート制限対応をSwiftで書き直す際の仕様書として使う(元マニュアル4章に詳細とファイル名一覧)。
これらのPythonファイルは別の一時作業環境にあり本セッションには存在しない可能性が高いので、
再現が必要な場合はユーザーに伝えてロジックを言語化してもらう。

## 未確定事項(実装前にユーザーと決める)

- Bot API / 個人アカウント方式のどちらを採用するか(両対応も選択肢)
- Live Photoの動画部分を送るかどうかのデフォルト挙動
- 配布方法: 個人のXcodeビルドのみ / App Store公開(Apple Developer Program登録・審査が必要)
- 対応する最低iOSバージョン

App Store配布を選ぶ場合、審査・アカウント登録はユーザー本人が行う(Apple Developer Programへの
登録はアカウント作成に該当するためClaudeは代行しない)。
