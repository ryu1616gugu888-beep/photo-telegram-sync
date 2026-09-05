import Foundation

/// 送信済みPHAsset.localIdentifierの集合と直近同期時刻を永続化する。
/// 重複排除はファイル名/サイズではなくlocalIdentifierで行う(元マニュアル3章の知見)。
final class SyncStateStore {
    private let defaults = UserDefaults.standard
    private let sentIdentifiersKey = "sentAssetLocalIdentifiers"
    private let lastSyncDateKey = "lastSyncDate"
    private let liveVideoPolicyKey = "sendLivePhotoVideoClip"
    private let onboardedKey = "hasCompletedOnboarding"

    var sentIdentifiers: Set<String> {
        get { Set(defaults.stringArray(forKey: sentIdentifiersKey) ?? []) }
        set { defaults.set(Array(newValue), forKey: sentIdentifiersKey) }
    }

    func markSent(_ localIdentifier: String) {
        var current = sentIdentifiers
        current.insert(localIdentifier)
        sentIdentifiers = current
    }

    var lastSyncDate: Date? {
        get { defaults.object(forKey: lastSyncDateKey) as? Date }
        set { defaults.set(newValue, forKey: lastSyncDateKey) }
    }

    /// Live Photoの動画クリップも送るかどうか。デフォルトは送らない(静止画のみ)。
    /// 元マニュアルの一括移行作業と同じ既定値を踏襲しつつ、設定画面から変更できる。
    var sendLivePhotoVideoClip: Bool {
        get { defaults.bool(forKey: liveVideoPolicyKey) }
        set { defaults.set(newValue, forKey: liveVideoPolicyKey) }
    }

    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: onboardedKey) }
        set { defaults.set(newValue, forKey: onboardedKey) }
    }
}
