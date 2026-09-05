import SwiftUI

/// Bot API方式のみ対応(初期MVP)。個人アカウント(MTProto)方式の追加はdev/CLAUDE.mdの未確定事項を参照。
/// Telegramを一度も使ったことがない一般ユーザーでも迷わず設定できるように、
/// BotFatherでのBot作成手順を画面内に明記し、chat_id取得はcurl等を使わず
/// アプリが自動検出するボタン(TelegramClient.fetchLatestChatID)で完結させている。
struct OnboardingView: View {
    let state: SyncStateStore
    let onCompleted: () -> Void

    @Environment(\.openURL) private var openURL

    @State private var botToken: String = ""
    @State private var chatID: String = ""
    @State private var errorMessage: String?
    @State private var isDetectingChatID = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("このアプリを使うには、あなた専用のTelegram Bot(送信専用の小さなロボットアカウント)を1つ用意する必要があります。難しく見えますが、初めてでも5分ほどで終わります。下の手順どおりに進めてください。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("手順1: Telegramアプリを用意する") {
                    Text("まだTelegramをiPhoneに入れていない場合は、先にインストールしてアカウント登録(電話番号でのSMS認証)を済ませてください。既にお使いの場合はこの手順は不要です。")
                        .font(.footnote)
                    Button {
                        openURL(URL(string: "https://apps.apple.com/app/telegram-messenger/id686449807")!)
                    } label: {
                        Label("App StoreでTelegramを開く", systemImage: "arrow.up.forward.app")
                    }
                }

                Section("手順2: BotFatherでBotを作る") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("下のボタンでBotFather(Telegram公式の「Bot作成係」アカウント)とのトーク画面が開きます。開いたら、そこで次の操作をしてください:")
                        Text("① 画面下部の「START」をタップ(または /start と入力して送信)")
                        Text("② /newbot と入力して送信")
                        Text("③ Botの表示名を好きに決めて送信(例: My Photo Sync)")
                        Text("④ Botのユーザー名を決めて送信。最後は必ず「bot」で終わる必要があります(例: my_photo_sync_bot)。使われていない名前ならそのまま登録されます")
                        Text("⑤ 成功すると「Use this token to access the HTTP API:」というメッセージと一緒に、英数字と記号が並ぶ長い文字列(トークン)が送られてきます。それをコピーして、下の欄に貼り付けてください")
                    }
                    .font(.footnote)

                    Button {
                        openURL(URL(string: "https://t.me/BotFather")!)
                    } label: {
                        Label("TelegramでBotFatherを開く", systemImage: "arrow.up.forward.app")
                    }

                    TextField("ここにBotトークンを貼り付け", text: $botToken)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("手順3: chat_idを自動取得する") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("① 手順2で作ったBotとのトーク画面に戻り、何でもいいので1通メッセージを送ってください(例:「test」でOK)")
                        Text("② このアプリに戻り、下の「chat_idを自動取得」をタップしてください。curlやターミナル操作は一切不要です")
                    }
                    .font(.footnote)

                    Button {
                        Task { await detectChatID() }
                    } label: {
                        if isDetectingChatID {
                            ProgressView()
                        } else {
                            Text("chat_idを自動取得")
                        }
                    }
                    .disabled(botToken.isEmpty || isDetectingChatID)

                    if !chatID.isEmpty {
                        Label("取得できました(chat_id: \(chatID))", systemImage: "checkmark.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(.green)
                    }
                }

                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).font(.footnote)
                }

                Section {
                    Text("入力されたBotトークン・chat_idは、この端末内のKeychainにのみ保存されます。開発者のサーバーには一切送信されません。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button("保存して開始") {
                        save()
                    }
                    .disabled(botToken.isEmpty || chatID.isEmpty)
                }
            }
            .navigationTitle("初期設定")
        }
    }

    private func detectChatID() async {
        errorMessage = nil
        isDetectingChatID = true
        defer { isDetectingChatID = false }
        switch await TelegramClient.fetchLatestChatID(botToken: botToken) {
        case .success(let id):
            chatID = id
        case .failure(let message):
            errorMessage = message
        }
    }

    private func save() {
        guard !botToken.isEmpty, !chatID.isEmpty else {
            errorMessage = "Botトークンとchat_idの両方を入力してください。"
            return
        }
        KeychainHelper.set(botToken, forKey: TelegramCredentialsKey.botToken)
        KeychainHelper.set(chatID, forKey: TelegramCredentialsKey.chatID)
        state.hasCompletedOnboarding = true
        onCompleted()
    }
}
