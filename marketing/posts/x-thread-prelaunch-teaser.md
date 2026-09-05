# 【下書き】X/Threads投稿文案(開発進捗の告知・複数パターン)

<!-- 実際の投稿はユーザー本人の承認を得てから行うこと(marketing/CLAUDE.md方針)。 -->

## パターンA: 開発進捗の共有
```
📱→✈️ iPhoneで撮った写真・動画を、自動でTelegramに送るアプリを作ってる。

☁️ Telegramは保存容量が無制限だから、iPhoneやiCloudの空き容量を気にしなくていいのが地味に強い。

🔒 開発者側は写真もパスワードも一切預からない設計にした。

⚙️ ソースコードはGitHubで公開中
https://github.com/ryu1616gugu888-beep/photo-telegram-sync

#個人開発 #iOSアプリ
```

## パターンB: 課題提起型
```
😮‍💨 Google Photosの無料枠、iCloudの容量アラート、正直もう疲れた。

💡 写真の保存先を「容量無制限のTelegram」に変える、というアプリを作っています。
撮った写真が自動でTelegram上のBotに届くだけのシンプルな仕組み。

⚙️ GitHubでソース公開中
https://github.com/ryu1616gugu888-beep/photo-telegram-sync

#個人開発
```

## パターンC: 開発の背景(実績訴求)
```
📦 以前、自分のGoogle Photos(2万枚以上)を丸ごとTelegramに移行したことがあって、
その知見をもとに「これから撮る分」も自動化するアプリを作っています。

📷 写真は原本画質のまま、動画も再エンコードなしで届くようにこだわりました。

🔗 気になった人はこちら
https://github.com/ryu1616gugu888-beep/photo-telegram-sync

#個人開発 #iOS
```

## 運用メモ
- ハッシュタグは投稿先のトレンドに応じて調整可能。
- 実際に投稿する前に、必ずユーザー本人に内容を確認してもらい、明示的な許可を得る(下書き保存まではここで完了、投稿操作はユーザーの判断)。
- 配布方針(2026-09-06決定): App Store公開は行わず、GitHub上でソースコードを公開する方針に確定。
  上記3パターンには**公開済みのGitHubリポジトリへのリンクを追加済み**
  (https://github.com/ryu1616gugu888-beep/photo-telegram-sync)。ダウンロードリンクではなく
  「ソースを見る/自分でビルドする」導線である点に注意。
