import Photos
import SwiftUI

/// Drives one swiping session. Items already reviewed in earlier days are skipped,
/// so every session continues from where the previous one stopped.
@MainActor
final class SessionViewModel: ObservableObject {
    struct HistoryEntry {
        let item: ReviewItem
        let decision: Decision
    }

    @Published private(set) var queue: [ReviewItem] = []
    @Published private(set) var history: [HistoryEntry] = []
    @Published private(set) var isLoading = true
    @Published private(set) var exhausted = false
    @Published var goalJustReached = false

    let category: MediaCategory
    let store: ProgressStore
    let library: PhotoLibraryService

    private var fetchResult: PHFetchResult<PHAsset>?
    private var cursor = 0
    private var reachedEnd = false
    private var isFilling = false
    private let batchSize = 15

    init(category: MediaCategory, store: ProgressStore, library: PhotoLibraryService) {
        self.category = category
        self.store = store
        self.library = library
    }

    var sessionReviewed: Int { history.count }
    var sessionDeleted: Int { history.filter { $0.decision == .delete }.count }
    var sessionDeleteBytes: Int64 {
        history.filter { $0.decision == .delete }.reduce(0) { $0 + $1.item.size }
    }
    var canUndo: Bool { !history.isEmpty }

    func start() {
        guard fetchResult == nil else { return }
        fetchResult = PhotoLibraryService.fetch(category: category, newestFirst: store.data.newestFirst)
        fill()
    }

    private func fill() {
        guard !isFilling, !reachedEnd, let result = fetchResult else { return }
        isFilling = true
        let start = cursor
        let limit = batchSize
        let skip = store.data.reviewedIDs.union(queue.map(\.id))
        let wa = library.whatsappIDs
        Task.detached(priority: .userInitiated) {
            var items: [ReviewItem] = []
            var i = start
            while i < result.count && items.count < limit {
                let asset = result.object(at: i)
                i += 1
                if skip.contains(asset.localIdentifier) { continue }
                items.append(ReviewItem(asset: asset,
                                        size: PhotoLibraryService.fileSize(of: asset),
                                        source: PhotoLibraryService.sourceLabel(for: asset, whatsappIDs: wa)))
            }
            let next = i
            let end = i >= result.count
            let batch = items
            await MainActor.run {
                self.appendBatch(batch, nextCursor: next, reachedEnd: end)
            }
        }
    }

    private func appendBatch(_ items: [ReviewItem], nextCursor: Int, reachedEnd end: Bool) {
        let existing = Set(queue.map(\.id))
        queue.append(contentsOf: items.filter { !existing.contains($0.id) && !store.data.reviewedIDs.contains($0.id) })
        cursor = nextCursor
        reachedEnd = end
        isFilling = false
        isLoading = false
        if queue.count < 5 && !reachedEnd {
            fill()
        } else if queue.isEmpty && reachedEnd {
            markExhausted()
        }
    }

    private func markExhausted() {
        exhausted = true
        store.markTodayComplete()
    }

    func decide(_ decision: Decision) {
        guard !queue.isEmpty else { return }
        let item = queue.removeFirst()
        let wasDone = store.data.todayReviewed >= store.data.dailyGoal
        store.record(decision, id: item.id, size: item.size)
        history.append(HistoryEntry(item: item, decision: decision))
        if !wasDone && store.data.todayReviewed >= store.data.dailyGoal {
            goalJustReached = true
        }
        if queue.count < 5 && !reachedEnd {
            fill()
        }
        if queue.isEmpty && reachedEnd {
            markExhausted()
        }
    }

    func undo() {
        guard let last = history.popLast() else { return }
        store.undo(last.decision, id: last.item.id)
        queue.insert(last.item, at: 0)
        exhausted = false
    }
}
