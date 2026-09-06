# CLAUDE.md (dev/ 専用: iOSアプリ開発)

このディレクトリは iPhone写真→Telegram自動転送アプリの実装(Swift/Xcode)を担当する。
ルートの [../CLAUDE.md](../CLAUDE.md) の方針を必ず先に守ること(特にオンデバイス処理・
認証情報非預かりの原則、api_id/api_hash非共有の原則)。技術知見の全文は
[../docs/photo_telegram_ios_app_manual.md](../docs/photo_telegram_ios_app_manual.md) を参照。

## 現在の状態(2026-09-06時点)

Xcode本体インストール済み(App Store経由、ユーザー対応済み)。`project.yml`(XcodeGen定義)から
`xcodegen generate` で `.xcodeproj` を生成してビルド・iOS Simulator実行できる状態。

- **中核パイプライン(PhotoKit→Telegram送信)はエンドツーエンドで検証済み**: オンボーディング→
  PhotoKit権限→「今すぐ同期」→実際のTelegram Bot APIへの送信、まで確認済み(2026-09-06、後述の
  タップ不具合が発生する"前"に確認したもの)。
- **既知の不具合(2026-09-06発見、未解決)**: 同日中に、Claude Code iOS SimulatorツールからのUIタップが
  本アプリの「今すぐ同期」ボタンに対してのみ反応しなくなる事象が発生。切り分けの結果:
  - Simulatorのタップ機構自体は正常(ホーム画面のアプリアイコン・システムの権限ダイアログのボタンは
    問題なく反応する)
  - アプリのプロセス自体はクラッシュせず起動し続けている(`launchctl list`で確認済み)
  - **ContentViewに追加したUI(容量無制限の説明ボックス)が原因ではない**(該当コードを一時的に
    削除して再ビルドしても再現した)
  - **特定のSimulatorデバイスの劣化状態が原因でもない**(全く新規に作成したデバイスでも同じ症状が再現した)
  - CoreSimulatorServiceの再起動、デバイスの完全な再起動、アプリの完全な再インストールでも解消しない
  - 根本原因は特定できなかった。最後に確実に成功したタップは、本日の早い段階(Live Photo配線修正・
    ContentViewのUI追加より前)。それ以降にコードが原因で壊れた形跡はない(上記の切り分けで否定済み)ため、
    実機またはXcodeからの直接インストール(`xcodebuild ... -destination 'platform=iOS Simulator'`
    ではなくXcode GUIでのRun)で同じ問題が起きるか確認するのが次の切り分けステップ。
- ユニットテスト12件(`dev/Tests/PhotoTelegramSyncTests/`)全て成功: 日付キャプション表示・
  FloodWait(429)リトライ・50MBサイズ上限。`xcodebuild test -project PhotoTelegramSync.xcodeproj
  -scheme PhotoTelegramSync -destination 'platform=iOS Simulator,id=<UDID>'` で実行できる。
- 132MBの実動画ファイル(ffmpegで生成、`xcrun simctl addmedia`でSimulatorに追加)でも
  サイズ超過スキップの実データ検証済み。
- **未検証: Live Photoの動画クリップ送信ロジック。** `PHAssetResourceType.pairedVideo`経由で実装は
  完了しているが、有効なLive Photo(HEIC+MOVペア、Appleの`ContentIdentifier`メタデータが一致して
  いる必要がある)をSimulator上で合成する試みは失敗し、AirDropでの実機→Mac受け渡しでもLive Photoの
  まま届かなかった(ポートレート/通常写真になった)。**次に検証するなら、実機に直接アプリをインストール
  してテストする必要がある**(TestFlightなしでもXcodeから実機ビルド・実行は可能)。
  GitHub Issueとして記録済み:
  [#1](https://github.com/ryu1616gugu888-beep/photo-telegram-sync/issues/1)。

`.xcodeproj` は `project.yml` から再生成可能なので意図的にgitignore対象にしている。
`project.yml`か`Sources/`/`Tests/`を変更したら都度 `xcodegen generate` を実行すること。

## Telegram Bot(検証用)

ユーザーが `@unlimited_photo_app_bot` を作成済み。トークンは `dev/.env.local`
(gitignore対象、平文で保存、Botトークンは疑似APIキーでありユーザーアカウント認証情報そのものではない)
に保存している。`scripts/telegram_api_check.sh` でXcodeなしでもBot API疎通・送信フォーマット
(document/video)をcurlベースで検証できる。chat_id取得にはユーザーがBotへ1通メッセージを送る操作が必要
(これも「相手アカウントでの操作」ではなく単なるメッセージ送信なので、都度これくらいの最小操作は
発生し得る)。DEBUG限定のURLスキーム(`phototelegramsync://debug-onboard?token=...&chatid=...`)で
Simulator上のオンボーディング手入力をスキップできる(Releaseビルドには含まれない)。

## アーキテクチャ要点(元マニュアルの要約、詳細は上記リンク先を参照)

- 写真アクセスは `PhotoKit`(`PHPhotoLibrary`権限)。`PHAsset.creationDate`/`location`/
  `mediaSubtypes`(Live Photo判定)/`localIdentifier`(重複排除キー)を使う。
- 送信フォーマットの使い分け(実装済み、変更する場合は必ず踏襲すること):
  - 写真は原本保持のため **document形式(force_document)** で送る(通常の写真送信は自動再圧縮される)。
  - 動画は逆に **"video"タイプ**で送る(documentだとサムネイルが出ない/再エンコードはされない)。
  - HEICはネイティブに`PHImageManager`でサムネイル生成できるので、旧Pythonスクリプトのような
    `sips`回避策は不要。
  - Live Photoは `PHAsset.mediaSubtypes.contains(.photoLive)` で判定。動画クリップ送信は
    `SyncStateStore.sendLivePhotoVideoClip`(デフォルトOFF)で制御(実装済み、実機検証は未了)。
- 重複排除は `PHAsset.localIdentifier` を送信済みリストとして永続化(UserDefaults)。
- Telegram送信は `FloodWaitError` 相当のレート制限が発生しうるため、指定秒数待ってリトライする
  実装済み(`TelegramClient`、テスト済み)。ファイルサイズ上限超過時はスキップ(実装・テスト済み)。
- バックグラウンド実行はiOSの制約で「撮影と同時に完全自動」は信頼性高く実現できない。現在は
  「アプリを開いたときに前回同期以降の差分をまとめて送る」同期ボタン方式のみ実装。
  `BGAppRefreshTask`併用は将来検討(未着手)。

## 決定事項

- **配布方法(2026-09-06決定、同日中に方針転換): App Storeでのリリースは費用対効果が薄いと判断し
  見送り。代わりにGitHub上でのソースコード公開(技術者が自分でXcodeビルドして使う形)+Web上での
  コンテンツ発信の2本柱に絞る。** 詳細な理由・トレードオフ・将来ストア配信を再検討する条件は
  [../marketing/business-plan.md](../marketing/business-plan.md)4節・4-補節を参照。
  App Store提出を将来的に目指す場合、現状の設計(単機能・フルアクセス要求)のままでは
  Appleの4.2(Minimum Functionality)等で却下リスクが高いことも同ドキュメントに調査済み。
  Apple Developer Program登録はアカウント作成にあたるため、その時点でも登録自体はユーザー本人が行う。
- **Telegram送信方式(2026-09-06決定): 当面Bot APIのみ。** 個人アカウント(MTProto)方式は将来の
  拡張候補として保留(下記「今後の拡張予定」参照)。
- **Live Photo動画クリップのデフォルト(2026-09-06決定): デフォルトOFFのまま**(静止画のみ送信)。
  以前の一括移行プロジェクトと同じ既定値。設定でONにできる実装は完了済み。
- **最低対応iOSバージョン(2026-09-06決定): iOS 17のまま。** 自分専用ビルドのため広い互換性は不要。

## 今後の拡張予定(今は着手しない)

- **個人アカウント(MTProto)方式の追加**: 2GB/4GB(Premium)まで送信可能になり、Bot APIの50MB上限を
  超える動画にも対応できる。ただし実装コストが大きい: Telegram公式のSwift向けMTProto実装は無く、
  TDLib(C++コア)をiOSプロジェクトに組み込むか、サードパーティのSwiftラッパーを使う必要があり、
  電話番号+SMSコード+(必要なら)2段階認証のログインフローも自前実装しなければならない。
  着手する場合は、まず「50MB上限で本当に困る場面が実際にあるか」を使ってみてから判断すること。
  着手時は各ユーザーが自分でmy.telegram.orgからapi_id/api_hashを取得する設計を厳守
  (../CLAUDE.mdの共有禁止の原則)。
