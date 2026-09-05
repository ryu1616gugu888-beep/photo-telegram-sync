import Foundation

/// Bot API経由でのTelegram送信ロジック。元マニュアル3章の知見をそのまま踏襲する:
/// - 写真は原本保持のため "document" として送る(通常の photo 送信は自動再圧縮されるため)
/// - 動画は "video" タイプで送る(document だとサムネイルが出ない)
/// - FloodWaitError相当(HTTP 429 / error_code 429)は retry_after 秒待ってリトライする
/// - Bot API のファイルサイズ上限(50MB)を超える場合は送らずスキップを返す
enum TelegramSendResult: Equatable {
    case success
    case skippedTooLarge(sizeBytes: Int)
    case failure(String)
}

enum ChatIDDetectionResult: Equatable {
    case success(String)
    case failure(String)
}

final class TelegramClient {
    /// Bot APIの1ファイルあたりの上限(50MB)。個人アカウント(MTProto)方式は対象外。
    static let maxFileSizeBytes = 50 * 1024 * 1024

    private let botToken: String
    private let chatID: String
    private let maxRetries = 3
    private let session: URLSession

    init(botToken: String, chatID: String, session: URLSession = .shared) {
        self.botToken = botToken
        self.chatID = chatID
        self.session = session
    }

    private func endpoint(_ method: String) -> URL {
        URL(string: "https://api.telegram.org/bot\(botToken)/\(method)")!
    }

    func sendDocument(fileData: Data, filename: String, caption: String?, thumbnail: Data? = nil) async -> TelegramSendResult {
        await send(method: "sendDocument", fileFieldName: "document", fileData: fileData,
                   filename: filename, caption: caption, thumbnail: thumbnail)
    }

    func sendVideo(fileData: Data, filename: String, caption: String?, thumbnail: Data? = nil) async -> TelegramSendResult {
        await send(method: "sendVideo", fileFieldName: "video", fileData: fileData,
                   filename: filename, caption: caption, thumbnail: thumbnail)
    }

    private func send(method: String, fileFieldName: String, fileData: Data, filename: String,
                       caption: String?, thumbnail: Data?, attempt: Int = 0) async -> TelegramSendResult {
        guard fileData.count <= Self.maxFileSizeBytes else {
            return .skippedTooLarge(sizeBytes: fileData.count)
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()

        func appendField(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        func appendFile(_ name: String, filename: String, data: Data, mimeType: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
            body.append(data)
            body.append("\r\n".data(using: .utf8)!)
        }

        appendField("chat_id", chatID)
        if let caption, !caption.isEmpty {
            appendField("caption", caption)
        }
        appendFile(fileFieldName, filename: filename, data: fileData, mimeType: "application/octet-stream")
        if let thumbnail {
            appendFile("thumb", filename: "thumb.jpg", data: thumbnail, mimeType: "image/jpeg")
        }
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        var request = URLRequest(url: endpoint(method))
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .failure("no HTTP response")
            }

            if http.statusCode == 429, attempt < maxRetries {
                let retryAfter = Self.parseRetryAfter(from: data) ?? 5
                try? await Task.sleep(nanoseconds: UInt64(retryAfter + 1) * 1_000_000_000)
                return await send(method: method, fileFieldName: fileFieldName, fileData: fileData,
                                   filename: filename, caption: caption, thumbnail: thumbnail, attempt: attempt + 1)
            }

            if (200..<300).contains(http.statusCode) {
                return .success
            }
            let body = String(data: data, encoding: .utf8) ?? "unknown error"
            return .failure("HTTP \(http.statusCode): \(body)")
        } catch {
            return .failure(error.localizedDescription)
        }
    }

    private static func parseRetryAfter(from data: Data) -> Int? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let parameters = json["parameters"] as? [String: Any],
              let retryAfter = parameters["retry_after"] as? Int else {
            return nil
        }
        return retryAfter
    }

    /// curlやAPIの知識がないユーザーでも設定できるように、getUpdatesを叩いて
    /// 直近でBotへメッセージを送ってきたchat_idを自動検出する(オンボーディング画面用)。
    static func fetchLatestChatID(botToken: String) async -> ChatIDDetectionResult {
        guard !botToken.isEmpty, let url = URL(string: "https://api.telegram.org/bot\(botToken)/getUpdates") else {
            return .failure("Botトークンの形式が正しくないようです。")
        }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return .failure("Telegramへの問い合わせに失敗しました。トークンをもう一度確認してください。")
            }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let ok = json["ok"] as? Bool, ok,
                  let results = json["result"] as? [[String: Any]] else {
                return .failure("応答の解析に失敗しました。")
            }
            guard let last = results.last,
                  let message = last["message"] as? [String: Any],
                  let chat = message["chat"] as? [String: Any],
                  let chatID = chat["id"] as? Int else {
                return .failure("まだBotへのメッセージが見つかりません。Botとのトーク画面で1通メッセージを送ってから、もう一度お試しください。")
            }
            return .success(String(chatID))
        } catch {
            return .failure("通信エラー: \(error.localizedDescription)")
        }
    }
}
