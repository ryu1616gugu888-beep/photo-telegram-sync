# 【下書き】note記事: 「自分でiPhoneの写真をTelegramに自動バックアップする方法」(DIY / アプリ不使用)

<!-- 公開先: note.com。他の記事(アプリの開発秘話・技術解説)とは独立した、
     純粋なハウツー記事という位置づけ。この記事内ではアプリの話は一切しない
     (ユーザー指示: 2026-09-08「アプリを作った点には触れず、自分でconsole等で
     やる場合どうしたら良いか」)。GitHubリンク等のCTAも入れない。 -->

## タイトル(SEO方針、business-plan.md 6節に準拠)

**「iPhoneの写真をTelegramに自動バックアップする方法(無料・アプリ不要・Mac+Pythonで実現)」**

## 想定読者

- iPhoneの写真をiCloud以外の場所にも無料でバックアップしたい人
- プログラミング初心者だが、ターミナルで簡単なコマンドを打つくらいは抵抗がない人
- Telegramを既に使っている、またはこれから使ってみたい人
- 「アプリを入れずに、自分の手元だけで完結する方法」を探している人

## 前提条件(この記事の対象範囲)

- **Mac(macOS)を持っていること**。この記事の方法はMacの「写真」Appの仕組みを使うため、Mac専用。
  Windowsのみで完結する方法は別の仕組みが必要になるため、この記事では扱わない。
- iPhoneとMacで同じApple IDを使っていること(iCloud写真での同期に必要)。
- Telegramのアカウントを持っていること(なければ無料ですぐ作れる)。
- ターミナル(ターミナル.app)を多少触ったことがある、またはこの記事のコマンドをそのままコピペできること。
- プログラミング経験は不要。ただしPython(プログラミング言語)を動かす環境を1つだけ用意する。

---

## 本文(確定稿)

# iPhoneの写真をTelegramに自動バックアップする方法(無料・アプリ不要・Mac+Pythonで実現)

iPhoneの写真、気づいたらiCloudの容量がいっぱいでは困っていませんか。この記事では、**新しいアプリを一切インストールせず**、Macとフリーのツールだけで「iPhoneで撮った写真を自動でTelegramに送って保存する」仕組みを作る方法を、初心者向けに手順通りに解説します。

Telegramはトーク上のファイル保存容量に実質的な上限がなく、無料で使えます。iPhone本体やiCloudの容量を圧迫せずに、写真のバックアップ先を増やせるのが最大のメリットです。

## この記事でやること・やらないこと

- やること: Mac上でiPhoneの写真を自動的にTelegramの「自分専用トーク(Botとのチャット)」に送る仕組みを、無料のツールだけで組み立てる
- やらないこと: 専用アプリの開発・インストール(この記事はアプリを使わない方法です)

全体の流れは次の4ステップです。

1. Telegramで自分専用の「Bot」を作る
2. iPhoneの写真をMacに自動で同期する設定をする
3. 新しい写真だけをTelegramに送るPythonスクリプトを用意する
4. 定期的に自動実行されるようにする

順番にやっていきましょう。

## ステップ1: Telegramで自分専用のBotを作る

TelegramのBot(ボット)は、プログラムから写真やメッセージを送るための「窓口」です。難しそうに聞こえますが、実際はTelegramの中にいる「BotFather」という公式Botとチャットするだけで作れます。

1. Telegramアプリで「BotFather」を検索して開く(公式マーク付きのアカウントであることを確認)
2. `/newbot` と送信する
3. Botの表示名を聞かれるので、好きな名前を入力する(例: 「MyPhotoBackup」)
4. Botのユーザー名を聞かれるので、末尾が`bot`で終わる一意な名前を入力する(例: `my_photo_backup_12345_bot`)
5. 作成が完了すると、**APIトークン**という文字列が発行される(`123456789:AAxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx` のような形式)

**このAPIトークンは、あなたのBotを誰でも操作できてしまう「パスワード」に相当します。**画面のスクリーンショットをSNSに上げたり、他人に共有したりしないでください。この記事内のスクリプトでも、トークンはあなたのMacの中だけに保存します。

次に、このBotとの1対1のトークを開始します。

1. 発行されたBotのユーザー名(`@my_photo_backup_12345_bot`など)を検索して開く
2. 「開始」または「Start」ボタンを押し、何かひとこと(「テスト」でよい)を送っておく

これで、あなたとBotとの間にトーク(チャット)が1つできました。

## ステップ2: chat_id(送り先ID)を取得する

Botにメッセージを送らせるには、「どのトーク宛てに送るか」を示す`chat_id`という数字が必要です。ターミナルから次のコマンドを実行して取得します(`<あなたのトークン>`の部分は、ステップ1で取得したトークンに置き換えてください)。

```bash
curl "https://api.telegram.org/bot<あなたのトークン>/getUpdates"
```

先ほどBotに送った「テスト」というメッセージの内容が入ったJSON(データのかたまり)が返ってきます。その中の`"chat":{"id":123456789,...}` という部分の数字が`chat_id`です。この数字をメモしておいてください。

もし何も返ってこない場合は、ステップ1で「開始」ボタンを押し忘れている、またはBotにまだ1通もメッセージを送っていない可能性があります。もう一度Botとのトークにメッセージを送ってから、同じコマンドを試してください。

## ステップ3: iPhoneの写真をMacに自動で同期する設定

Telegramに送るには、まずiPhoneの写真がMac側でも見られる状態になっている必要があります。iCloud写真を使えば、これは自動化できます。

**iPhone側の設定**:
1. 「設定」→ 自分の名前 → 「iCloud」→「写真」
2. 「このiPhoneを同期」(または「iCloud写真」)をオンにする

**Mac側の設定**:
1. 「写真」Appを開く
2. メニューバーの「写真」→「設定」(または「環境設定」)→「iCloud」タブ
3. 「iCloud写真」にチェックを入れる
4. 「オリジナルをこのMacにダウンロード」を選ぶ(「Macのストレージを最適化」のままだと、圧縮版しか手元に無い写真が出てくるため、原本を確実に扱いたい場合はこちらを推奨)

設定後、iPhoneで撮った写真は、Wi-Fi環境下でMacの「写真」Appにも自動的に反映されるようになります(反映まで数分〜数十分かかることがあります)。

## ステップ4: 新しい写真だけをTelegramに送るスクリプトを用意する

ここからはターミナルでの作業です。「写真」Appの中身を直接フォルダとして扱うのは大変なので、[osxphotos](https://github.com/RhetTbull/osxphotos)というオープンソースの無料ツールを使い、「写真」Appから普通のフォルダへ写真を書き出します。

### 3-1. 必要なツールをインストールする

Homebrew(Macの定番パッケージ管理ツール)が入っていない場合は、先に[公式サイト](https://brew.sh)の手順でインストールしてください。入っていれば、以下だけでOKです。

```bash
brew install python3
pip3 install osxphotos requests
```

### 3-2. 作業用フォルダを作る

```bash
mkdir -p ~/TelegramPhotoSync/export
```

### 3-3. スクリプトを作成する

`~/TelegramPhotoSync/sync.py` というファイルを作り、以下の内容を貼り付けます(エディタは「テキストエディット」でも、VS Codeなど使い慣れたものでも構いません)。

```python
import os
import glob
import subprocess
import time
import requests

# ==== ここを自分の値に書き換える ====
BOT_TOKEN = "ここにステップ1で取得したAPIトークンを貼り付け"
CHAT_ID = "ここにステップ2で取得したchat_idを貼り付け"
# ===================================

EXPORT_DIR = os.path.expanduser("~/TelegramPhotoSync/export")
SENT_LOG = os.path.expanduser("~/TelegramPhotoSync/sent.txt")
MAX_BYTES = 50 * 1024 * 1024  # Telegram Bot APIの送信上限(50MB)
TARGET_EXTENSIONS = (".jpg", ".jpeg", ".png", ".heic", ".mov", ".mp4")


def export_new_photos():
    """「写真」Appから、前回以降に増えた分だけをフォルダへ書き出す"""
    os.makedirs(EXPORT_DIR, exist_ok=True)
    subprocess.run(
        ["osxphotos", "export", EXPORT_DIR, "--update"],
        check=True,
    )


def load_sent_log():
    if not os.path.exists(SENT_LOG):
        return set()
    with open(SENT_LOG, "r") as f:
        return set(line.strip() for line in f)


def append_sent_log(filename):
    with open(SENT_LOG, "a") as f:
        f.write(filename + "\n")


def send_to_telegram(filepath):
    ext = os.path.splitext(filepath)[1].lower()
    is_video = ext in (".mov", ".mp4")
    method = "sendVideo" if is_video else "sendDocument"
    field = "video" if is_video else "document"

    url = f"https://api.telegram.org/bot{BOT_TOKEN}/{method}"
    with open(filepath, "rb") as f:
        response = requests.post(
            url,
            data={"chat_id": CHAT_ID},
            files={field: f},
            timeout=120,
        )

    if response.status_code == 429:
        retry_after = response.json().get("parameters", {}).get("retry_after", 5)
        print(f"送信間隔が短すぎるため{retry_after}秒待機します")
        time.sleep(retry_after + 1)
        return send_to_telegram(filepath)

    response.raise_for_status()


def main():
    export_new_photos()
    sent = load_sent_log()

    all_files = sorted(
        glob.glob(os.path.join(EXPORT_DIR, "**", "*.*"), recursive=True)
    )
    new_files = [
        f
        for f in all_files
        if os.path.basename(f) not in sent
        and os.path.splitext(f)[1].lower() in TARGET_EXTENSIONS
    ]

    print(f"新しく見つかった写真・動画: {len(new_files)}件")

    for filepath in new_files:
        filename = os.path.basename(filepath)

        if os.path.getsize(filepath) > MAX_BYTES:
            print(f"スキップ(50MB超のため送信不可): {filename}")
            append_sent_log(filename)  # 毎回スキップし続けないよう記録だけしておく
            continue

        try:
            send_to_telegram(filepath)
            append_sent_log(filename)
            print(f"送信完了: {filename}")
            time.sleep(1)  # 連続送信で制限にかからないよう少し間隔をあける
        except Exception as e:
            print(f"送信失敗: {filename} ({e})")


if __name__ == "__main__":
    main()
```

`BOT_TOKEN`と`CHAT_ID`の部分を、ステップ1・2で取得した自分の値に必ず書き換えてください。

### 3-4. 初回に「フルディスクアクセス」の許可を出す

`osxphotos`は「写真」Appのライブラリに直接アクセスするため、初回実行時にターミナル(または使っているエディタ)へのアクセス許可を求められます。「システム設定」→「プライバシーとセキュリティ」→「フルディスクアクセス」で、ターミナルにチェックを入れてください。許可しないと写真の書き出しに失敗します。

### 3-5. 試しに1回動かしてみる

```bash
python3 ~/TelegramPhotoSync/sync.py
```

「送信完了: ○○.jpg」のようなログが流れ、Telegramの自分のトークに写真が届けば成功です。初回はこれまでの写真すべてが対象になるため、枚数が多いと時間がかかります。2回目以降は前回からの差分(新しく撮った写真)だけが送られます。

## ステップ5: 定期的に自動実行されるようにする

このままでは「手動で実行したときだけ」動く状態です。1時間おきなど、定期的に自動実行されるように設定しましょう。macOSの`cron`という仕組みを使います。

```bash
crontab -e
```

エディタが開くので、以下の1行を追記します(`0 * * * *` は「毎時0分に実行」の意味です)。

```
0 * * * * /usr/bin/python3 /Users/あなたのユーザー名/TelegramPhotoSync/sync.py >> /Users/あなたのユーザー名/TelegramPhotoSync/log.txt 2>&1
```

保存して終了すると設定完了です。実行結果は`~/TelegramPhotoSync/log.txt`に記録されていくので、うまくいっているか時々確認するとよいでしょう。

`cron`から実行する場合も、ターミナル(正確には`cron`を実行しているプロセス)にフルディスクアクセスの許可が必要になることがあります。うまく動かない場合は、「システム設定」→「プライバシーとセキュリティ」→「フルディスクアクセス」の一覧を確認してください。

## 注意点・よくあるつまずきポイント

- **Macがスリープしていると同期されません。** この方法はMacが起動していて、かつiCloud写真の同期が進んでいる状態が前提です。「システム設定」の電源関連の項目で、Wi-Fi接続中はスリープしない設定にしておくと安定します。
- **50MBを超える動画は送れません。** これはTelegram Bot APIの仕様上の制限です。大きな動画は自動送信の対象から外れる(スクリプト内でスキップされる)ので、必要であれば手動で個別に送ってください。
- **APIトークンは絶対に公開しない。** GitHubなどにコードを公開する場合は、トークンを直接書かず、環境変数などに分離することを強く推奨します。
- **Live Photoの動画部分は今回のスクリプトの対象外です。** 静止画部分のみが送信されます。
- 初回実行時、これまで撮りためた写真の枚数が多いと、Telegram側のレート制限(短時間の連続送信への制限)に引っかかることがあります。スクリプト内で自動的に待機して再送信するようにしているので、時間はかかりますが基本的に放置で完了します。

## まとめ

Telegramの無料Bot機能と、Macの「写真」App、そしてオープンソースの`osxphotos`を組み合わせることで、専用アプリを使わずに「iPhoneで撮った写真を自動でバックアップする仕組み」を無料で作れます。一度設定してしまえば、あとは撮るだけで自動的にバックアップが積み上がっていきます。iCloudの容量に悩んでいる方は、ぜひ試してみてください。

---

## トーン・注意点(執筆メモ)

- ユーザー指示により、この記事内ではアプリ開発の話・GitHubへのリンク等は一切含めない(他記事とは独立した純粋なハウツーとして扱う)。
- 誇張表現を避ける(marketing/CLAUDE.md方針)。「無料」「アプリ不要」は事実として正確(osxphotos・Python・Homebrewはいずれも無料)。
- 公開前に、本文中のトークン例(`123456789:AAxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`)が実在するBotの実トークンと一致しないダミー値であることを再確認済み。
- osxphotosはRhett Turnbull氏によるオープンソースツール(Apache License 2.0)。記事内でリンクを明記し、開発元への言及を欠かさないこと。
