import Foundation

/// PHAssetの撮影日時・位置情報からTelegram送信キャプションを組み立てる純粋ロジック。
/// PHAsset(ユニットテストでは直接生成できない)に依存しない形にすることで、
/// 日付フォーマット・タイムゾーンの表示崩れをユニットテストで検証できるようにしている。
enum CaptionFormatter {
    static func caption(
        creationDate: Date?,
        latitude: Double?,
        longitude: Double?,
        calendar: Calendar = .current,
        timeZone: TimeZone = .current
    ) -> String {
        var parts: [String] = []
        if let creationDate {
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.timeZone = timeZone
            formatter.dateFormat = "yyyy-MM-dd HH:mm"
            parts.append(formatter.string(from: creationDate))
        }
        if let latitude, let longitude {
            parts.append("https://maps.google.com/?q=\(latitude),\(longitude)")
        }
        return parts.joined(separator: "\n")
    }
}
