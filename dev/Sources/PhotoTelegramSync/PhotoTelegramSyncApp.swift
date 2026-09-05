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
            if onboarded {
                ContentView(state: state)
            } else {
                OnboardingView(state: state) {
                    onboarded = true
                }
            }
        }
    }
}
