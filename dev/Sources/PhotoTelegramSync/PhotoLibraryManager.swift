import Foundation
import Photos
import UIKit

enum SyncProgress {
    case idle
    case running(processed: Int, total: Int)
    case finished(sent: Int, skipped: Int, failed: Int)
}

/// 「前回同期時刻以降の新規PHAssetをまとめて送信する」同期ボタン方式(元マニュアル2-3節・案1)。
final class PhotoLibraryManager {
    private let state: SyncStateStore
    private let telegram: TelegramClient

    init(state: SyncStateStore, telegram: TelegramClient) {
        self.state = state
        self.telegram = telegram
    }

    func requestAuthorizationIfNeeded() async -> PHAuthorizationStatus {
        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if current == .notDetermined {
            return await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        }
        return current
    }

    func syncNewAssets(progress: @escaping (SyncProgress) -> Void) async {
        let fetchOptions = PHFetchOptions()
        if let since = state.lastSyncDate {
            fetchOptions.predicate = NSPredicate(format: "creationDate > %@", since as NSDate)
        }
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

        let assets = PHAsset.fetchAssets(with: fetchOptions)
        let alreadySent = state.sentIdentifiers
        var pending: [PHAsset] = []
        assets.enumerateObjects { asset, _, _ in
            if !alreadySent.contains(asset.localIdentifier) {
                pending.append(asset)
            }
        }

        guard !pending.isEmpty else {
            progress(.finished(sent: 0, skipped: 0, failed: 0))
            return
        }

        var sent = 0, skipped = 0, failed = 0
        for (index, asset) in pending.enumerated() {
            progress(.running(processed: index, total: pending.count))
            let result = await sendAsset(asset)
            switch result {
            case .success:
                state.markSent(asset.localIdentifier)
                sent += 1
            case .skippedTooLarge:
                skipped += 1
            case .failure:
                failed += 1
            }
        }
        state.lastSyncDate = Date()
        progress(.finished(sent: sent, skipped: skipped, failed: failed))
    }

    private func sendAsset(_ asset: PHAsset) async -> TelegramSendResult {
        let caption = captionFor(asset)

        guard let data = await originalData(for: asset) else {
            return .failure("could not load original data for \(asset.localIdentifier)")
        }

        switch asset.mediaType {
        case .video:
            // 動画は再エンコードされない"video"タイプで送る(documentだとサムネイルが出ない)。
            let thumb = await thumbnailJPEG(for: asset)
            return await telegram.sendVideo(fileData: data, filename: "\(asset.localIdentifier).mov",
                                             caption: caption, thumbnail: thumb)
        case .image:
            // 写真は自動再圧縮を避けるためdocument形式(force_document相当)で送る。
            let thumb = await thumbnailJPEG(for: asset)
            return await telegram.sendDocument(fileData: data, filename: "\(asset.localIdentifier).heic",
                                                caption: caption, thumbnail: thumb)
        default:
            return .failure("unsupported media type for \(asset.localIdentifier)")
        }
    }

    private func captionFor(_ asset: PHAsset) -> String {
        var parts: [String] = []
        if let date = asset.creationDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm"
            parts.append(formatter.string(from: date))
        }
        if let location = asset.location {
            let lat = location.coordinate.latitude
            let lon = location.coordinate.longitude
            parts.append("https://maps.google.com/?q=\(lat),\(lon)")
        }
        return parts.joined(separator: "\n")
    }

    private func originalData(for asset: PHAsset) async -> Data? {
        guard let resource = PHAssetResource.assetResources(for: asset).first(where: {
            $0.type == .photo || $0.type == .video || $0.type == .fullSizePhoto
        }) else { return nil }

        return await withCheckedContinuation { continuation in
            var data = Data()
            let options = PHAssetResourceRequestOptions()
            options.isNetworkAccessAllowed = true
            PHAssetResourceManager.default().requestData(for: resource, options: options, dataReceivedHandler: { chunk in
                data.append(chunk)
            }, completionHandler: { error in
                continuation.resume(returning: error != nil ? nil : data)
            })
        }
    }

    private func thumbnailJPEG(for asset: PHAsset) async -> Data? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isSynchronous = false
            options.deliveryMode = .fastFormat
            PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 320, height: 320),
                                                   contentMode: .aspectFit, options: options) { image, _ in
                continuation.resume(returning: image?.jpegData(compressionQuality: 0.7))
            }
        }
    }
}
