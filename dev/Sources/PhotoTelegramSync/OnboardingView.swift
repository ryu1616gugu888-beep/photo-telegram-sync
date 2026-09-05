import SwiftUI

/// Bot API方式のみ対応(初期MVP)。個人アカウント(MTProto)方式の追加はdev/CLAUDE.mdの未確定事項を参照。
struct OnboardingView: View {
    let state: SyncStateStore
    let onCompleted: () -> Void

    @State private var botToken: String = ""
    @State private var chatID: String = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("TelegramのBotトークンとchat_idを入力してください。これらは端末内のKeychainにのみ保存され、開発者のサーバーには一切送信されません。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Bot API設定") {
                    TextField("Botトークン", text: $botToken)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("chat_id", text: $chatID)
                        .keyboardType(.numbersAndPunctuation)
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).font(.footnote)
                }
                Section {
                    Button("保存して開始") {
                        save()
                    }
                    .disabled(botToken.isEmpty || chatID.isEmpty)
                }
            }
            .navigationTitle("初期設定")
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
