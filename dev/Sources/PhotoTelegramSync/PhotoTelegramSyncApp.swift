import SwiftUI

@main
struct PhotoTelegramSyncApp: App {
    private let state = SyncStateStore()
    @State private var onboarded: Bool

    init() {
        _onboarded = State(initialValue: SyncStateStore().hasCompletedOnboarding)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if onboarded {
                    ContentView(state: state)
                } else {
                    OnboardingView(state: state) {
                        onboarded = true
                    }
                }
            }
            #if DEBUG
            .onOpenURL { url in
                handleDebugOnboardURL(url)
            }
            #endif
        }
    }

    #if DEBUG
    /// Simulator上の自動テスト専用。SwiftUIのTextFieldへの合成タップがフォーカスを取れない環境向けに、
    /// `phototelegramsync://debug-onboard?token=...&chatid=...` で初期設定をスキップできるようにする。
    /// Releaseビルドには含まれない。
    private func handleDebugOnboardURL(_ url: URL) {
        guard url.scheme == "phototelegramsync", url.host == "debug-onboard",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let token = components.queryItems?.first(where: { $0.name == "token" })?.value,
              let chatID = components.queryItems?.first(where: { $0.name == "chatid" })?.value else {
            return
        }
        KeychainHelper.set(token, forKey: TelegramCredentialsKey.botToken)
        KeychainHelper.set(chatID, forKey: TelegramCredentialsKey.chatID)
        state.hasCompletedOnboarding = true
        onboarded = true
    }
    #endif
}
