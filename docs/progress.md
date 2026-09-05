# 進捗ログ

新しい特化型Claude Codeセッションはここを読めば現在地が分かる。1エントリ1〜2行で追記していく。

## 2026-09-05

- プロジェクト一式を `~/Projects/photo-telegram-app` に新規作成(ルートCLAUDE.md + `dev/` + `marketing/`)。
- 元マニュアル(`docs/photo_telegram_ios_app_manual.md`)を配置。
- Obsidian Vault(`開発ログ/写真Telegram自動転送アプリ 進捗状況.md`)に状況サマリーノートを配置。
- ユーザー方針「実機検証も含め介入は最小限に(今後共通)」を受け、Step1(ショートカットプロトタイプ)は
  スキップし、直接Xcodeネイティブアプリ実装に着手する方針へ転換。
- **重要な発見**: このMacにXcode本体が未インストール(Command Line Toolsのみ)。ビルド・Simulator
  検証はXcodeインストール後でないと不可。App Store経由のインストールはApple ID認証を伴うため
  ユーザー本人の対応が必要(未対応・依頼中)。
- XcodeGenを導入し、`dev/project.yml` + `dev/Sources/PhotoTelegramSync/` にSwiftソース一式
  (Keychain保存/重複排除状態管理/TelegramClient(document・video送信・FloodWaitリトライ・
  50MB上限チェック)/PhotoKit同期ロジック/オンボーディング/メイン画面/App本体)を実装。
  `xcodegen generate` での `.xcodeproj` 生成まで確認済み(Xcode本体なしでも検証できた範囲)。
- ユーザーが `@unlimited_photo_app_bot` を作成、トークンを共有 → `dev/.env.local`(gitignore対象)に保存。
  ユーザーがBotへ1通メッセージを送信 → chat_id(`REDACTED_CHAT_ID`)取得に成功。
  `scripts/telegram_api_check.sh send_document` で実際に document 送信が成功(疎通確認済み)。
  Telegram送信ロジックの中核(認証・multipart送信)は実機Xcodeなしで実証済み。
- 次のアクション: ユーザーがApp StoreからXcodeをインストール → `dev/`で`xcodegen generate && open
  PhotoTelegramSync.xcodeproj`してSimulatorビルド・PhotoKit権限フロー・写真同期を検証。

## 2026-09-06

- Xcodeインストール完了(ユーザー対応)。ライセンス同意・`xcode-select`設定・iOS Simulatorランタイムの
  ダウンロードも実施(途中、xcode-select未確定のまま複数回ダウンロードが走り重複ディスクイメージが
  発生したため削除して整理)。iPhone 17 Pro Simulatorでビルド・起動に成功。
- オンボーディング画面がTelegram未経験者には不親切(Botトークン/chat_idの取得方法が書かれていない、
  chat_id取得がcurl前提)と判明したため、画面内にBotFatherでのBot作成手順を全文明記し、chat_id取得は
  `TelegramClient.fetchLatestChatID()`でアプリが自動検出するボタンに変更(curl不要に)。
- Simulator上のテキストフィールドへのtapが最初効かなかった問題は、実は座標系の誤解(スクリーンショット
  画像のピクセル座標をそのままdevice point座標として使っていた)が原因と判明。ボタンタップで実際に
  ラベルが変化する基準点から逆算してスケール(実測: 約0.438 pt/px)を較正し直したら正しく動作した。
  次回もこのツールで座標を使う際は、まず既知のUI要素タップで座標系を較正してから使うこと。
- TextFieldへの入力自体は上記較正で解決可能だが、検証を早めるため、DEBUG限定のURLスキーム
  (`phototelegramsync://debug-onboard?token=...&chatid=...`)を追加し、オンボーディング画面の
  手入力をスキップしてTelegram認証情報を直接注入できるようにした(`PhotoTelegramSyncApp.swift`、
  Releaseビルドには含まれない)。
- **PhotoKit権限フロー(カスタムの日本語説明文が正しく表示されることも確認)→「今すぐ同期」→実際の
  Telegram Bot APIへの送信、という中核機能のエンドツーエンド検証に成功。** Simulatorの標準サンプル
  写真6枚すべてが実際にBot(`@unlimited_photo_app_bot`)経由で送信され、アプリの結果表示は
  「完了: 6件送信 / 0件サイズ超過スキップ / 0件失敗」。iOS版アプリの中核パイプラインは実質的に完成。
- 次のアクション: Live Photo・大容量動画・FloodWait時の挙動など細かいケースの検証、オンボーディング
  画面自体の実機(またはSimulatorでの手入力)での見た目確認、`marketing/`側の着手。
