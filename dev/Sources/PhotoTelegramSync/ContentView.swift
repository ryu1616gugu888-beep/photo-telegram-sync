import SwiftUI
import Photos

struct ContentView: View {
    let state: SyncStateStore

    @State private var statusText: String = "「今すぐ同期」をタップすると、前回同期以降の新しい写真・動画をTelegramへ送信します。"
    @State private var isSyncing = false
    @State private var authStatus: PHAuthorizationStatus = .notDetermined

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text(statusText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                if let lastSync = state.lastSyncDate {
                    Text("前回同期: \(lastSync.formatted(date: .abbreviated, time: .shortened))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Button {
                    Task { await runSync() }
                } label: {
                    if isSyncing {
                        ProgressView()
                    } else {
                        Text("今すぐ同期")
                            .font(.headline)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSyncing)

                VStack(alignment: .leading, spacing: 8) {
                    Label("送信した写真・動画は、あなたのTelegramで開いているBotとのトーク画面にそのまま届きます。アプリ内には一覧表示はありません(Telegramが保管場所です)。", systemImage: "paperplane.fill")
                    Label("Telegram上のファイルは容量無制限。iPhone本体やiCloudの空き容量を一切消費せずに保存し続けられます。", systemImage: "externaldrive.badge.checkmark")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding()
            .navigationTitle("写真Telegram同期")
            .task {
                authStatus = await requestAuthorization()
            }
        }
    }

    private func requestAuthorization() async -> PHAuthorizationStatus {
        let manager = PhotoLibraryManager(state: state, telegram: makeClient())
        return await manager.requestAuthorizationIfNeeded()
    }

    private func runSync() async {
        guard authStatus == .authorized || authStatus == .limited else {
            statusText = "写真ライブラリへのアクセスが許可されていません。設定アプリから許可してください。"
            return
        }
        isSyncing = true
        let manager = PhotoLibraryManager(state: state, telegram: makeClient())
        await manager.syncNewAssets { progress in
            switch progress {
            case .idle:
                break
            case .running(let processed, let total):
                statusText = "送信中... (\(processed)/\(total))"
            case .finished(let sent, let skipped, let failed):
                statusText = "完了: \(sent)件送信 / \(skipped)件サイズ超過スキップ / \(failed)件失敗"
            }
        }
        isSyncing = false
    }

    private func makeClient() -> TelegramClient {
        let token = KeychainHelper.get(TelegramCredentialsKey.botToken) ?? ""
        let chatID = KeychainHelper.get(TelegramCredentialsKey.chatID) ?? ""
        return TelegramClient(botToken: token, chatID: chatID)
    }
}
