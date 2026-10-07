import Photos
import UIKit

enum MediaCategory: String, CaseIterable, Identifiable {
    case all, photos, videos, screenshots, whatsapp

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "הכל"
        case .photos: return "תמונות"
        case .videos: return "סרטונים"
        case .screenshots: return "צילומי מסך"
        case .whatsapp: return "וואטסאפ"
        }
    }

    var icon: String {
        switch self {
        case .all: return "square.grid.2x2.fill"
        case .photos: return "photo.fill"
        case .videos: return "video.fill"
        case .screenshots: return "iphone"
        case .whatsapp: return "message.fill"
        }
    }
}

struct ReviewItem: Identifiable, Equatable {
    let asset: PHAsset
    let size: Int64
    let source: String

    var id: String { asset.localIdentifier }
    var isVideo: Bool { asset.mediaType == .video }

    static func == (lhs: ReviewItem, rhs: ReviewItem) -> Bool { lhs.id == rhs.id }
}

@MainActor
final class PhotoLibraryService: ObservableObject {
    @Published private(set) var authStatus: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    @Published private(set) var totalCount = 0
    @Published private(set) var remaining: [MediaCategory: Int] = [:]
    @Published private(set) var isCounting = false
    @Published private(set) var hasWhatsAppAlbum = false
    private(set) var whatsappIDs: Set<String> = []

    var hasAccess: Bool { authStatus == .authorized || authStatus == .limited }

    // MARK: - Authorization

    func refreshAuthorization() {
        authStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    func requestAuthorization() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        authStatus = status
    }

    // MARK: - Fetching

    nonisolated static func baseOptions(newestFirst: Bool) -> PHFetchOptions {
        let o = PHFetchOptions()
        o.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: !newestFirst)]
        // Only items that live in the user's library can be deleted (not shared albums / synced).
        o.includeAssetSourceTypes = [.typeUserLibrary]
        return o
    }

    /// On iPhone, WhatsApp saves media into an album called "WhatsApp" (when "Save to Camera Roll" is on).
    nonisolated static func whatsappAlbum() -> PHAssetCollection? {
        let albums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)
        var found: PHAssetCollection?
        albums.enumerateObjects { collection, _, stop in
            let title = collection.localizedTitle ?? ""
            if title.localizedCaseInsensitiveContains("whatsapp") || title.contains("וואטסאפ") {
                found = collection
                stop.pointee = true
            }
        }
        return found
    }

    nonisolated static func fetch(category: MediaCategory, newestFirst: Bool) -> PHFetchResult<PHAsset> {
        let o = baseOptions(newestFirst: newestFirst)
        let image = PHAssetMediaType.image.rawValue
        let video = PHAssetMediaType.video.rawValue
        switch category {
        case .all:
            o.predicate = NSPredicate(format: "mediaType == %d OR mediaType == %d", image, video)
            return PHAsset.fetchAssets(with: o)
        case .photos:
            o.predicate = NSPredicate(format: "mediaType == %d", image)
            return PHAsset.fetchAssets(with: o)
        case .videos:
            o.predicate = NSPredicate(format: "mediaType == %d", video)
            return PHAsset.fetchAssets(with: o)
        case .screenshots:
            o.predicate = NSPredicate(format: "mediaType == %d AND (mediaSubtypes & %d) != 0",
                                      image, Int(PHAssetMediaSubtype.photoScreenshot.rawValue))
            return PHAsset.fetchAssets(with: o)
        case .whatsapp:
            guard let album = whatsappAlbum() else {
                return PHAsset.fetchAssets(withLocalIdentifiers: [], options: nil)
            }
            o.predicate = NSPredicate(format: "mediaType == %d OR mediaType == %d", image, video)
            return PHAsset.fetchAssets(in: album, options: o)
        }
    }

    nonisolated static func fileSize(of asset: PHAsset) -> Int64 {
        var total: Int64 = 0
        for resource in PHAssetResource.assetResources(for: asset) {
            if let n = resource.value(forKey: "fileSize") as? NSNumber {
                total += n.int64Value
            }
        }
        return total
    }

    nonisolated static func sourceLabel(for asset: PHAsset, whatsappIDs: Set<String>) -> String {
        if whatsappIDs.contains(asset.localIdentifier) { return "וואטסאפ" }
        if asset.mediaSubtypes.contains(.photoScreenshot) { return "צילום מסך" }
        if asset.mediaType == .video { return "סרטון" }
        return "מצלמה"
    }

    // MARK: - Counting

    func refreshCounts(reviewed: Set<String>, newestFirst: Bool) {
        guard hasAccess, !isCounting else { return }
        isCounting = true
        Task.detached(priority: .userInitiated) {
            var waIDs = Set<String>()
            let album = PhotoLibraryService.whatsappAlbum()
            if let album {
                PHAsset.fetchAssets(in: album, options: nil).enumerateObjects { a, _, _ in
                    waIDs.insert(a.localIdentifier)
                }
            }
            let all = PhotoLibraryService.fetch(category: .all, newestFirst: newestFirst)
            var counts: [MediaCategory: Int] = [:]
            all.enumerateObjects { a, _, _ in
                if reviewed.contains(a.localIdentifier) { return }
                counts[.all, default: 0] += 1
                if a.mediaType == .video {
                    counts[.videos, default: 0] += 1
                } else {
                    counts[.photos, default: 0] += 1
                    if a.mediaSubtypes.contains(.photoScreenshot) { counts[.screenshots, default: 0] += 1 }
                }
                if waIDs.contains(a.localIdentifier) { counts[.whatsapp, default: 0] += 1 }
            }
            let total = all.count
            let finalCounts = counts
            let finalWA = waIDs
            let hasAlbum = album != nil
            await MainActor.run {
                self.totalCount = total
                self.remaining = finalCounts
                self.whatsappIDs = finalWA
                self.hasWhatsAppAlbum = hasAlbum
                self.isCounting = false
            }
        }
    }

    // MARK: - Applying changes (each shows the iOS system confirmation)

    nonisolated static func existingIDs(_ ids: [String]) -> Set<String> {
        guard !ids.isEmpty else { return [] }
        var found = Set<String>()
        PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil).enumerateObjects { a, _, _ in
            found.insert(a.localIdentifier)
        }
        return found
    }

    nonisolated static func assets(for ids: [String]) -> [PHAsset] {
        guard !ids.isEmpty else { return [] }
        var list: [PHAsset] = []
        PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil).enumerateObjects { a, _, _ in
            list.append(a)
        }
        return list
    }

    func markFavorites(ids: [String]) async -> Bool {
        let assets = Self.assets(for: ids)
        guard !assets.isEmpty else { return true }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                for asset in assets {
                    PHAssetChangeRequest(for: asset).isFavorite = true
                }
            }
            return true
        } catch {
            return false
        }
    }

    /// Deleted items go to "Recently Deleted" in the Photos app for 30 days.
    func delete(ids: [String]) async -> Bool {
        let assets = Self.assets(for: ids)
        guard !assets.isEmpty else { return true }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(assets as NSArray)
            }
            return true
        } catch {
            return false
        }
    }
}

struct StorageInfo {
    let total: Int64
    let available: Int64

    var used: Int64 { max(0, total - available) }
    var usedFraction: Double { total > 0 ? Double(used) / Double(total) : 0 }

    static func current() -> StorageInfo? {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        guard let values = try? url.resourceValues(forKeys: [.volumeTotalCapacityKey,
                                                             .volumeAvailableCapacityForImportantUsageKey]),
              let total = values.volumeTotalCapacity,
              let available = values.volumeAvailableCapacityForImportantUsage else { return nil }
        return StorageInfo(total: Int64(total), available: available)
    }
}
