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
