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
  ユーザーがBotへ1通メッセージを送信 → chat_id取得に成功(値は`dev/.env.local`のみに保存、
  gitには含めない)。
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
  アセットでの動作確認はまだ済んでいない。
  ユーザーが実機からAirDropでの受け渡しも試したが、Mac側にLive Photoとして届かなかった
  (Photos.appで確認した3枚はいずれも「LIVE」ではなく「PORTRAIT」または通常写真として着地した。
  ポートレートモードとLive Photoは同時撮影できない点、およびAirDrop受け渡し時にLive情報が
  落ちるケースがある点が要因と考えられる)。**Live Photo動画クリップ送信ロジックの実機検証は
  引き続き未了。次回、実際にLive Photoモードで撮影した素材を使うか、実機に直接アプリをインストール
  して検証する必要がある。**
- ContentViewに「送信した写真はTelegramの当該Botとのトーク画面で確認できる」「Telegramは容量無制限で
  iPhone本体/iCloudの容量を消費しない」という案内をUIに追加。実機同然の画面で表示確認済み。

### marketing/ 側
- note記事下書き(`articles/dev-story-privacy-first-photo-sync.md`): 開発の背景、Telegram容量無制限
  という強み、プライバシー設計、同期した写真の見方、を含めて構成案を作成。
- 短編動画台本2本(`videos/`): 「容量、もう気にしてない」フック版、「2万枚移行の裏話」版。
- SNS投稿文3パターン(`posts/x-thread-prelaunch-teaser.md`)。全て下書きのみ、投稿は未実施
  (投稿にはユーザー本人の明示的な許可が必要)。

## 2026-09-06(続き): 残りの未確定事項を決定

`dev/CLAUDE.md`の未確定事項3点をユーザーと確認し、全て決定済みにした:
- Telegram送信方式: 当面Bot APIのみ。個人アカウント(MTProto)は将来の拡張候補として保留
  (TDLib組み込み等、実装コストが大きいため今は着手しない)。
- Live Photo動画クリップ: デフォルトOFFのまま(静止画のみ送信)。
- 最低対応iOSバージョン: iOS 17のまま(自分専用ビルドのため広い互換性は不要)。

これで実装済み範囲での未確定事項はなし。次に手をつけるとすれば、Live Photoの実機検証
(Simulator/AirDropいずれも失敗済みのため実機への直接インストールが必要)か、marketing下書きの
内容レビュー。

## 2026-09-06(続き): marketing下書きレビュー + 事業計画書作成 + 競合調査

- marketing下書き3本(note記事・動画台本2本)をレビューし、以下を修正:
  - アプリ画面収録時に実際のBotユーザー名・chat_idが映り込まないよう注意書きを追加
  - 競合スクショ使用時の権利配慮の注意書きを追加
  - Google Photos有料化に関する記述は公開前に事実確認する旨を明記
- **`marketing/business-plan.md`を新規作成。** これまで散在していた前提(ターゲット層・差別化・
  収益化の考え方・配布方針との整合)を1箇所に集約。今後判断に迷ったらまずここを見る。
- **競合調査を実施(WebSearch)**: 「iPhone写真→Telegram自動転送」を謳う既存のネイティブiOSアプリは
  見つからず(ニッチが空いている可能性)。ただし類似発想として (1) IFTTT/Makeの「写真追加→Telegram
  送信」レシピが既に存在(→ サードパーティクラウドを経由しない点・原本画質保持が差別化材料になる)、
  (2) PhotoSync(定番の写真転送アプリ)はTelegramを送信先に含んでいない、(3) TG-Photos(GitHub、
  Docker運用の自己ホスト型・iOSアプリではない)という近接ツールを確認。
  また「Telegramを無制限クラウードとして使う」という切り口自体は英語圏では既出だが日本語ではまだ
  少ないと判明 → note記事は「発見した」ではなく「自動化アプリを作った」を主軸にする方針を明記。
- 詳細・出典URLは`marketing/business-plan.md`5節を参照。
- 次のアクション: App Store内での直接検索(Web検索とは別)、事業計画書を踏まえたmarketing下書きの
  本文レビュー・自然な日本語への整形。

## 2026-09-06(さらに続き): 配布方針を大きく転換(App Store断念→GitHub公開+Web発信)

- ユーザー判断: **App Storeリリースは費用対効果が薄いため見送り。** 代わりに
  (1) GitHub上でのソースコード公開(技術者が自分でXcodeビルドして使う形)、
  (2) note等Web上でのコンテンツ発信、の2本柱に絞る方針に転換。
- **将来のストア配信リスクを事前調査(Apple公式Review Guidelines)**: 現状の設計(単機能・
  フルアクセス要求)のままではMinimum Functionality(4.2)等で却下リスクが高いと判明。
  詳細・出典・再検討する条件(意思決定ゲート)は`marketing/business-plan.md`4-補節に記録。
- **重要な発見・対応**: GitHub公開を見据えてgit履歴を監査した結果、`docs/progress.md`の1コミットに
  実際のTelegram chat_id(ユーザーの内部ID)が平文で残っていたため、現在のファイル内容は修正済み
  (ただし過去コミットの履歴自体はまだ残っている。実際に公開する前に履歴の書き換えが必要)。
  Botトークン等の秘密情報の漏洩は無いことを確認済み。
- `CLAUDE.md`(ルート)・`dev/CLAUDE.md`・`marketing/CLAUDE.md`・`marketing/business-plan.md`を
  この方針転換に合わせて更新済み。
- 次のアクション: 実際にGitHubリポジトリを公開する前に、過去コミット履歴の書き換え(秘密情報除去)、
  README整備、ライセンス選定を行う。

## 2026-09-06(さらに続き): GitHub公開の準備(履歴書き換え・README・LICENSE)

- **公開用ハンドルネームを`lulu_234582`に決定**(本名「Luca Tsunoda」は公開しない)。コミット用
  メールは仮に`lulu_234582@users.noreply.github.com`を設定(GitHubアカウント作成後、実際のnoreply
  アドレスに要差し替え)。
- `git-filter-repo`(brewでインストール)を使い、過去コミット履歴を書き換え:
  1. 実chat_id(`docs/progress.md`に平文で残っていたもの)を全履歴から除去済み
  2. 全コミットの著者名・メールを実名からハンドルネームへ書き換え済み
  (リポジトリはまだどこにもpushしていないため、安全に書き換えられた)
- リポジトリ直下に`README.md`(概要・強み・セットアップ/テスト手順)と`LICENSE`(MIT、著作者は
  ハンドルネーム)を新規作成、コミット済み。
- ローカルのgit `user.name`/`user.email`をこのリポジトリ内でハンドルネームに設定済み(グローバル設定は
  変更していないため、他のリポジトリには影響しない)。
- **公開完了(2026-09-06)**: `gh repo create`で https://github.com/ryu1616gugu888-beep/photo-telegram-sync
  を作成しpush済み(public)。既存のポートフォリオ用GitHubアカウント配下で公開する形でユーザーに
  最終確認済み(コミット表示名は`lulu_234582`のまま、リポジトリの置き場所はアカウントに紐づく)。
- 次のアクション: marketing下書きのCTAにこのリポジトリへのリンクを追加する、Live Photoの実機検証。

## 2026-09-06(さらに続き): READMEの拡充・SEO方針の策定・CTAへのリンク追加

- **README.mdを大幅拡充**: 「なぜ作ったのか」(開発の動機)、「こんな人におすすめ」、Telegram Bot作成
  手順込みの丁寧な「使い方」を追加。タイトル・冒頭文も検索されやすいキーワード
  (iPhone・写真・Telegram・自動バックアップ・容量無制限)を前半に配置する形に変更。
- **`marketing/business-plan.md`にSEO・検索性の方針セクション(6節)を新設**: README/note記事/動画/
  SNS投稿すべてに共通するタイトルの付け方(核心キーワードを前半に、感情フックを後半に)を明文化。
  note記事タイトルを1つに確定、短編動画2本の投稿タイトル/概要欄も追加。
- marketing下書き3本(note記事・動画台本2本・SNS投稿3パターン)のCTAに、公開済みGitHubリポジトリ
  (https://github.com/ryu1616gugu888-beep/photo-telegram-sync )へのリンクを追加。
- README変更をGitHubへpush。

## 2026-09-06(さらに続き): note記事の見た目調整・公開、SNS/動画の視覚素材追加

- note記事にカバー画像(オリジナルイラスト)・見出しスタイル(6箇所)を適用。
- SNS投稿3パターンに絵文字・行間を追加して可読性向上。
- 短編動画2本用に縦型(9:16)サムネイル画像を新規作成
  (`marketing/videos/thumbnails/`)、各台本から参照。
- **note記事、公開済み**: https://note.com/mute_cedum909/n/n83b9772e9c59
  (note.com上の表示名: 「lulu@アプリ作りたい」)。公開はユーザー本人が実施。
- **X(Twitter)への投稿もユーザー本人が公開済み**(2026-09-06。投稿URLは未共有、パターンA〜Cの
  いずれかを使用したと思われる)。
- marketing下書き(note記事・短編動画2本・SNS投稿3パターン)は一通り公開/公開準備完了の段階に到達。
- 次のアクション: Live Photoの実機検証、オンボーディング画面の最終見た目確認、短編動画の実際の撮影・編集。

## 2026-09-06(さらに続き): 動画1本目のドラフトを組み立て

- Simulatorでの画面録画+実機操作の自動化を試みたが、`recordVideo`実行中(および終了後も再現)に
  タップ入力が一切UIに反映されなくなる不具合に遭遇(原因未特定、再現性あり)。深追いせず方針転換。
- 代わりに、既にキャプチャ済みの実際のアプリ静止画(同期画面・初期設定画面)+新規作成のオリジナル
  イラスト(タイトル/課題提起/GitHub告知スライド)をffmpegでKen Burns風ズーム+結合し、
  動画1「容量、もう気にしてないんだよね」の**ドラフト動画(24秒、無音・字幕なし)**を完成させた。
  → `marketing/videos/drafts/video1_storage_anxiety_draft.mp4`
- 実際のBotユーザー名・chat_idの映り込みなしを確認済み。
- 次のアクション: ナレーション/字幕/BGMの追加(現状は素材組み立てのみ)、動画2本目の同様の制作、
  Simulatorのタップ入力不具合の原因調査(急ぎではない)。
