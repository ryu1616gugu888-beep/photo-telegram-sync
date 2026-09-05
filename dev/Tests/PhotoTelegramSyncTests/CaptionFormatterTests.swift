import XCTest
@testable import PhotoTelegramSync

/// 「写真が実際の撮影日付通りにキャプション表示されるか」を検証する回帰テスト。
/// PHAssetを直接生成できないため、日付フォーマットロジックをCaptionFormatterへ切り出してテストする。
final class CaptionFormatterTests: XCTestCase {
    private let jst = TimeZone(identifier: "Asia/Tokyo")!
    private let gregorian = Calendar(identifier: .gregorian)

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        var components = DateComponents()
        components.year = year; components.month = month; components.day = day
        components.hour = hour; components.minute = minute
        components.timeZone = jst
        return gregorian.date(from: components)!
    }

    func testCaption_formatsKnownDateExactlyAsCaptured() {
        let captured = date(2026, 3, 14, 9, 5)
        let caption = CaptionFormatter.caption(creationDate: captured, latitude: nil, longitude: nil,
                                                calendar: gregorian, timeZone: jst)
        XCTAssertEqual(caption, "2026-03-14 09:05")
    }

    func testCaption_padsSingleDigitMonthDayHourMinute() {
        let captured = date(2026, 1, 2, 3, 4)
        let caption = CaptionFormatter.caption(creationDate: captured, latitude: nil, longitude: nil,
                                                calendar: gregorian, timeZone: jst)
        XCTAssertEqual(caption, "2026-01-02 03:04", "1桁の月日時分が0埋めされず表示崩れするバグを防ぐ")
    }

    func testCaption_handlesLeapDayCorrectly() {
        let captured = date(2024, 2, 29, 23, 59)
        let caption = CaptionFormatter.caption(creationDate: captured, latitude: nil, longitude: nil,
                                                calendar: gregorian, timeZone: jst)
        XCTAssertEqual(caption, "2024-02-29 23:59")
    }

    func testCaption_multiplePhotosAcrossDatesPreserveChronologicalStrings() {
        // 前回同期以降にまたがる複数の日付が、それぞれ取り違えなく別々の文字列になることを確認
        let older = date(2025, 6, 15, 8, 0)
        let newer = date(2026, 9, 1, 21, 30)
        let olderCaption = CaptionFormatter.caption(creationDate: older, latitude: nil, longitude: nil,
                                                     calendar: gregorian, timeZone: jst)
        let newerCaption = CaptionFormatter.caption(creationDate: newer, latitude: nil, longitude: nil,
                                                     calendar: gregorian, timeZone: jst)
        XCTAssertEqual(olderCaption, "2025-06-15 08:00")
        XCTAssertEqual(newerCaption, "2026-09-01 21:30")
        XCTAssertNotEqual(olderCaption, newerCaption)
    }

    func testCaption_includesGoogleMapsLinkWhenLocationPresent() {
        let caption = CaptionFormatter.caption(creationDate: nil, latitude: 35.681236, longitude: 139.767125)
        XCTAssertEqual(caption, "https://maps.google.com/?q=35.681236,139.767125")
    }

    func testCaption_combinesDateAndLocationOnSeparateLines() {
        let captured = date(2026, 5, 1, 12, 0)
        let caption = CaptionFormatter.caption(creationDate: captured, latitude: 34.6937, longitude: 135.5023,
                                                calendar: gregorian, timeZone: jst)
        XCTAssertEqual(caption, "2026-05-01 12:00\nhttps://maps.google.com/?q=34.6937,135.5023")
    }

    func testCaption_emptyWhenNeitherDateNorLocationAvailable() {
        XCTAssertEqual(CaptionFormatter.caption(creationDate: nil, latitude: nil, longitude: nil), "")
    }
}
