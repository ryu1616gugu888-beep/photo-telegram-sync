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

## 2026-09-06(続き): dev/とmarketing/を並行実施

### dev/ 側
- キャプションの日付フォーマットをPHAssetに依存しない`CaptionFormatter`へ切り出し、XCTestを追加
  (`dev/Tests/PhotoTelegramSyncTests/`)。1桁月日・うるう日・複数日付の混在・位置情報付与など
  7ケースで「撮影日時通りに正しく表示されるか」を回帰テスト化、全て成功。
- `TelegramClient`にモックURLSession(`MockURLProtocol`)を使ったテストを追加し、実サーバーに触れずに
  FloodWait(429)時のリトライ成功・リトライ上限到達時の失敗・ちょうど上限サイズの許容、を検証。全て成功。
- `xcodebuild test`実行結果: **12件全て成功**。
- 実データでの追加検証: ffmpegで132MBの動画を生成し`xcrun simctl addmedia`でSimulatorに追加 → 同期
  実行 →「1件サイズ超過スキップ」を実機同然の環境で確認(モックだけでなく実ファイルでも動作確認済み)。
- **バグ修正**: `sendLivePhotoVideoClip`設定が実装コードに配線されておらず死んでいた
  (Live Photoの動画クリップを送る設定をONにしても何も起きない状態)。`PHAssetResourceType.pairedVideo`
  を取得して送信するロジックを実装し、正しく配線した(デフォルトはOFFのまま)。
- **既知の制約**: 有効なLive Photo(HEIC+MOVのペア、Appleの`ContentIdentifier`メタデータが一致している
  必要がある)をSimulator上でゼロから合成する試みは失敗(exiftoolでの`ContentIdentifier`書き込みが
  反映されない)。このため上記の配線修正はコードレビューレベルでは正しいはずだが、実際のLive Photo
  アセットでの動作確認はまだ済んでいない。**次回、実機で撮ったLive Photoを使って検証する必要あり。**
- ContentViewに「送信した写真はTelegramの当該Botとのトーク画面で確認できる」「Telegramは容量無制限で
  iPhone本体/iCloudの容量を消費しない」という案内をUIに追加。実機同然の画面で表示確認済み。

### marketing/ 側
- note記事下書き(`articles/dev-story-privacy-first-photo-sync.md`): 開発の背景、Telegram容量無制限
  という強み、プライバシー設計、同期した写真の見方、を含めて構成案を作成。
- 短編動画台本2本(`videos/`): 「容量、もう気にしてない」フック版、「2万枚移行の裏話」版。
- SNS投稿文3パターン(`posts/x-thread-prelaunch-teaser.md`)。全て下書きのみ、投稿は未実施
  (投稿にはユーザー本人の明示的な許可が必要)。
