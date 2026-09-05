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
