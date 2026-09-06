# 【下書き】Zenn記事: 技術解説編

<!-- 公開先: Zenn(https://zenn.dev)。note記事より技術者向けの深掘り版という位置づけ。
     Zennは「本」ではなく「記事(Article)」形式、Markdownでそのまま投稿できる。
     タグ候補: swift, ios, telegram, photokit -->

## タイトル(SEO方針、business-plan.md 6節に準拠)

**「PhotoKit + Telegram Bot APIでiPhoneの写真を自動バックアップするアプリを作った(Swift実装解説)」**

## 想定読者
- Swift/iOS開発者
- PhotoKitやTelegram Bot APIを触ったことがある/興味がある人
- 個人開発でのテスト戦略・プロジェクト構成に興味がある人

---

## 本文(確定稿)

# PhotoKit + Telegram Bot APIでiPhoneの写真を自動バックアップするアプリを作った

iPhoneの写真ライブラリを監視して、新しく追加された写真・動画を自動でTelegramへ転送するiOSアプリを作った。オンデバイス処理のみでサーバーは一切経由しない。ソースコードはGitHubで公開している。

https://github.com/ryu1616gugu888-beep/photo-telegram-sync

この記事では、実装上のポイントをいくつか technical に紹介する。

## 差分検知: PHAssetをcreationDateで絞り込む

iOSはサードパーティアプリの常時バックグラウンド実行を強く制限しているため、「撮影と同時に自動送信」は信頼性高くは実現できない。そこで、アプリを開いたときに前回同期以降の新規`PHAsset`をまとめて送る「同期ボタン」方式にした。

```swift
let fetchOptions = PHFetchOptions()
if let since = state.lastSyncDate {
    fetchOptions.predicate = NSPredicate(format: "creationDate > %@", since as NSDate)
}
fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
let assets = PHAsset.fetchAssets(with: fetchOptions)
```

重複排除は`PHAsset.localIdentifier`を送信済みリストとしてUserDefaultsに永続化する方式。ファイル名やサイズでの重複判定より確実。

## 写真はdocument、動画はvideoタイプで送る

Telegram Bot APIで写真を「photo」として送ると自動的に再圧縮される。原本画質を保ちたいので、写真は`sendDocument`で送る。一方、動画は逆に「video」タイプで送らないとサムネイルが生成されない(documentだと汎用アイコンになる)。この使い分けは実装上ハマりやすいポイントだった。

## FloodWait(429)のリトライ実装

Telegramへの連続送信はレート制限(`HTTP 429`、`retry_after`秒)に引っかかることがある。指定秒数待ってから再試行する必要がある。

```swift
if http.statusCode == 429, attempt < maxRetries {
    let retryAfter = Self.parseRetryAfter(from: data) ?? 5
    try? await Task.sleep(nanoseconds: UInt64(retryAfter + 1) * 1_000_000_000)
    return await send(method: method, ..., attempt: attempt + 1)
}
```

## テスト戦略: PHAssetは直接生成できない

`PHAsset`はイニシャライザが公開されていないため、ユニットテストで直接インスタンス化できない。そこで、日付・位置情報からキャプション文字列を組み立てるロジックを`PHAsset`に依存しない純粋関数(`CaptionFormatter`)として切り出し、そこだけをテスト対象にした。

```swift
enum CaptionFormatter {
    static func caption(creationDate: Date?, latitude: Double?, longitude: Double?, ...) -> String
}
```

Telegram送信のリトライロジックは、`URLProtocol`をサブクラス化したモックを使い、実サーバーに触れずにFloodWaitのリトライ・成功パスをテストしている。

```swift
final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (Int, [String: Any]))?
    // ...
}
```

この2つの工夫で、実機・Simulatorがなくても`xcodebuild test`だけでロジックの回帰テストができるようにした。

## プロジェクト構成: XcodeGenでxcodeprojをgit管理しない

`.xcodeproj`はバイナリに近いXML形式でマージが辛いので、[XcodeGen](https://github.com/yonaskolb/XcodeGen)の`project.yml`から都度生成する方式にし、`.xcodeproj`自体はgitignoreしている。

```bash
cd dev
xcodegen generate
xcodebuild test -project PhotoTelegramSync.xcodeproj -scheme PhotoTelegramSync \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

## 今後の課題

- Live Photoの動画クリップ送信は実装済みだが、Simulatorでの合成テストに失敗しており、実機での検証が残っている([Issue #1](https://github.com/ryu1616gugu888-beep/photo-telegram-sync/issues/1))
- より大きなファイル(2GB/4GB)に対応する個人アカウント(MTProto)方式は未着手

ソースは全部公開しているので、気になった人はぜひ見てみてほしい。issueやPRも歓迎。

https://github.com/ryu1616gugu888-beep/photo-telegram-sync

---

## トーン・注意点
- コードスニペットは実装からの抜粋であることを明記し、簡略化している旨を書く(完全な実装はリポジトリ参照)。
- 実際のBotトークン・chat_id等は一切含めない(既にコード内に存在しないことを確認済み)。
