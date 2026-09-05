import XCTest
@testable import PhotoTelegramSync

/// URLSessionをすり替えて、実際のTelegramサーバーに触れずにFloodWait(429)リトライや
/// レスポンス解析を検証するためのモック。
final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (Int, [String: Any]))?
    static var requestCount = 0

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        MockURLProtocol.requestCount += 1
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        do {
            let (statusCode, jsonBody) = try handler(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: statusCode,
                                            httpVersion: "HTTP/1.1", headerFields: nil)!
            let data = try JSONSerialization.data(withJSONObject: jsonBody)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

final class TelegramClientTests: XCTestCase {
    override func setUp() {
        super.setUp()
        MockURLProtocol.requestCount = 0
        MockURLProtocol.requestHandler = nil
    }

    private func mockedClient() -> TelegramClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return TelegramClient(botToken: "TEST_TOKEN", chatID: "12345", session: URLSession(configuration: config))
    }

    // MARK: - FloodWait (429) retry

    func testSendDocument_retriesAfterFloodWaitThenSucceeds() async {
        MockURLProtocol.requestHandler = { _ in
            if MockURLProtocol.requestCount == 1 {
                return (429, ["ok": false, "parameters": ["retry_after": 1]])
            }
            return (200, ["ok": true, "result": ["message_id": 1]])
        }

        let result = await mockedClient().sendDocument(fileData: Data("dummy".utf8), filename: "a.txt", caption: nil)

        XCTAssertEqual(result, .success)
        XCTAssertEqual(MockURLProtocol.requestCount, 2, "429を受けて1回リトライし、成功するまで送信されるはず")
    }

    func testSendDocument_givesUpAfterMaxRetries() async {
        MockURLProtocol.requestHandler = { _ in
            (429, ["ok": false, "parameters": ["retry_after": 0]])
        }

        let result = await mockedClient().sendDocument(fileData: Data("dummy".utf8), filename: "a.txt", caption: nil)

        if case .failure = result {
            // maxRetries(3)を使い切って失敗として返るのが正しい挙動
        } else {
            XCTFail("常に429が続く場合はリトライ上限で失敗として扱われるべき: \(result)")
        }
    }

    // MARK: - retry_afterの解析

    func testParseRetryAfter_extractsValueFromFloodWaitBody() {
        let json = try! JSONSerialization.data(withJSONObject: [
            "ok": false,
            "error_code": 429,
            "parameters": ["retry_after": 7]
        ])
        XCTAssertEqual(TelegramClient.parseRetryAfter(from: json), 7)
    }

    func testParseRetryAfter_returnsNilForOrdinarySuccessBody() {
        let json = try! JSONSerialization.data(withJSONObject: ["ok": true, "result": ["message_id": 1]])
        XCTAssertNil(TelegramClient.parseRetryAfter(from: json))
    }

    // MARK: - ファイルサイズ上限(Bot API 50MB)

    func testSendDocument_skipsFilesOverBotAPILimitWithoutNetworkCall() async {
        let oversized = Data(count: TelegramClient.maxFileSizeBytes + 1)

        let result = await mockedClient().sendDocument(fileData: oversized, filename: "big.mov", caption: nil)

        XCTAssertEqual(result, .skippedTooLarge(sizeBytes: TelegramClient.maxFileSizeBytes + 1))
        XCTAssertEqual(MockURLProtocol.requestCount, 0, "サイズ超過はネットワーク送信を試みる前に弾かれるべき")
    }

    func testSendVideo_allowsFileExactlyAtSizeLimit() async {
        MockURLProtocol.requestHandler = { _ in (200, ["ok": true, "result": ["message_id": 1]]) }
        let atLimit = Data(count: TelegramClient.maxFileSizeBytes)

        let result = await mockedClient().sendVideo(fileData: atLimit, filename: "at_limit.mov", caption: nil)

        XCTAssertEqual(result, .success)
    }
}
