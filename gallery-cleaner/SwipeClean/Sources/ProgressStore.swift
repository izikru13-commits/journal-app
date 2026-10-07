import Foundation

enum Decision: String, Codable {
    case keep, delete, favorite
}

/// Everything the app remembers between launches. Stored as JSON in Application Support.
struct ProgressData: Codable {
    var onboarded = false

    /// Every asset the user already swiped on (any direction). Sessions skip these,
    /// so each day continues exactly where the previous one stopped.
    var reviewedIDs: Set<String> = []

    /// Marked for deletion but not yet deleted (nothing is deleted without confirmation).
    var pendingDeletes: [String] = []
    var pendingDeleteSizes: [String: Int64] = [:]
    /// Marked as favorite, applied to the Photos library on confirmation.
    var pendingFavorites: [String] = []

    var totalFreedBytes: Int64 = 0
    var totalDeleted = 0
    var totalReviewed = 0
    var totalFavorited = 0

    /// Days ("yyyy-MM-dd") on which the daily goal was completed — drives the streak.
    var completedDays: Set<String> = []
    var dayKey = ""
    var todayReviewed = 0

    // Settings
    var dailyGoal = 50
    var reminderEnabled = true
    var reminderHour = 20
    var reminderMinute = 0
    var newestFirst = false

    init() {}

    enum CodingKeys: String, CodingKey {
        case onboarded, reviewedIDs, pendingDeletes, pendingDeleteSizes, pendingFavorites
        case totalFreedBytes, totalDeleted, totalReviewed, totalFavorited
        case completedDays, dayKey, todayReviewed
        case dailyGoal, reminderEnabled, reminderHour, reminderMinute, newestFirst
    }

    // Tolerant decoding so adding fields in future versions never wipes progress.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = ProgressData()
        onboarded = try c.decodeIfPresent(Bool.self, forKey: .onboarded) ?? d.onboarded
        reviewedIDs = try c.decodeIfPresent(Set<String>.self, forKey: .reviewedIDs) ?? d.reviewedIDs
        pendingDeletes = try c.decodeIfPresent([String].self, forKey: .pendingDeletes) ?? d.pendingDeletes
        pendingDeleteSizes = try c.decodeIfPresent([String: Int64].self, forKey: .pendingDeleteSizes) ?? d.pendingDeleteSizes
        pendingFavorites = try c.decodeIfPresent([String].self, forKey: .pendingFavorites) ?? d.pendingFavorites
        totalFreedBytes = try c.decodeIfPresent(Int64.self, forKey: .totalFreedBytes) ?? d.totalFreedBytes
        totalDeleted = try c.decodeIfPresent(Int.self, forKey: .totalDeleted) ?? d.totalDeleted
        totalReviewed = try c.decodeIfPresent(Int.self, forKey: .totalReviewed) ?? d.totalReviewed
        totalFavorited = try c.decodeIfPresent(Int.self, forKey: .totalFavorited) ?? d.totalFavorited
        completedDays = try c.decodeIfPresent(Set<String>.self, forKey: .completedDays) ?? d.completedDays
        dayKey = try c.decodeIfPresent(String.self, forKey: .dayKey) ?? d.dayKey
        todayReviewed = try c.decodeIfPresent(Int.self, forKey: .todayReviewed) ?? d.todayReviewed
        dailyGoal = try c.decodeIfPresent(Int.self, forKey: .dailyGoal) ?? d.dailyGoal
        reminderEnabled = try c.decodeIfPresent(Bool.self, forKey: .reminderEnabled) ?? d.reminderEnabled
        reminderHour = try c.decodeIfPresent(Int.self, forKey: .reminderHour) ?? d.reminderHour
        reminderMinute = try c.decodeIfPresent(Int.self, forKey: .reminderMinute) ?? d.reminderMinute
        newestFirst = try c.decodeIfPresent(Bool.self, forKey: .newestFirst) ?? d.newestFirst
    }
}

struct DayDot: Identifiable {
    let id: Int
    let label: String
    let done: Bool
    let isToday: Bool
}

@MainActor
final class ProgressStore: ObservableObject {
    @Published private(set) var data: ProgressData

    private let fileURL: URL
    private let saveQueue = DispatchQueue(label: "swipeclean.progress.save", qos: .utility)

    nonisolated static var defaultURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("progress.json")
    }

    init(fileURL: URL = ProgressStore.defaultURL, startFresh: Bool = false) {
        self.fileURL = fileURL
        if startFresh { try? FileManager.default.removeItem(at: fileURL) }
        if let raw = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(ProgressData.self, from: raw) {
            data = decoded
        } else {
            data = ProgressData()
        }
        rollDayIfNeeded()
    }

    // MARK: - Persistence

    private func save() {
        let snapshot = data
        let url = fileURL
        saveQueue.async {
            if let raw = try? JSONEncoder().encode(snapshot) {
                try? raw.write(to: url, options: .atomic)
            }
        }
    }

    /// Blocks until pending writes hit disk (used by tests).
    func waitForSave() {
        saveQueue.sync {}
    }

    func update(_ change: (inout ProgressData) -> Void) {
        change(&data)
        save()
    }

    // MARK: - Days & streak

    nonisolated static func key(for date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    func rollDayIfNeeded() {
        let today = Self.key(for: Date())
        if data.dayKey != today {
            data.dayKey = today
            data.todayReviewed = 0
            save()
        }
    }

    var todayDone: Bool { data.completedDays.contains(Self.key(for: Date())) }

    var streak: Int {
        let cal = Calendar.current
        var day = Date()
        if !data.completedDays.contains(Self.key(for: day)) {
            day = cal.date(byAdding: .day, value: -1, to: day) ?? day
        }
        var count = 0
        while data.completedDays.contains(Self.key(for: day)) {
            count += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return count
    }

    /// The last 7 days, oldest first, for the streak dots.
    var lastSevenDays: [DayDot] {
        let cal = Calendar.current
        let names = ["א׳", "ב׳", "ג׳", "ד׳", "ה׳", "ו׳", "ש׳"]
        var result: [DayDot] = []
        for offset in (0..<7).reversed() {
            guard let d = cal.date(byAdding: .day, value: -offset, to: Date()) else { continue }
            let weekday = cal.component(.weekday, from: d)
            result.append(DayDot(id: offset, label: names[weekday - 1],
                                 done: data.completedDays.contains(Self.key(for: d)), isToday: offset == 0))
        }
        return result
    }

    // MARK: - Decisions

    func record(_ decision: Decision, id: String, size: Int64) {
        rollDayIfNeeded()
        data.reviewedIDs.insert(id)
        data.totalReviewed += 1
        data.todayReviewed += 1
        switch decision {
        case .keep:
            break
        case .delete:
            if !data.pendingDeletes.contains(id) { data.pendingDeletes.append(id) }
            data.pendingDeleteSizes[id] = size
        case .favorite:
            if !data.pendingFavorites.contains(id) { data.pendingFavorites.append(id) }
        }
        if data.todayReviewed >= data.dailyGoal {
            data.completedDays.insert(data.dayKey)
        }
        save()
    }

    func undo(_ decision: Decision, id: String) {
        data.reviewedIDs.remove(id)
        data.totalReviewed = max(0, data.totalReviewed - 1)
        data.todayReviewed = max(0, data.todayReviewed - 1)
        switch decision {
        case .keep:
            break
        case .delete:
            data.pendingDeletes.removeAll { $0 == id }
            data.pendingDeleteSizes[id] = nil
        case .favorite:
            data.pendingFavorites.removeAll { $0 == id }
        }
        if data.todayReviewed < data.dailyGoal {
            data.completedDays.remove(data.dayKey)
        }
        save()
    }

    /// Called when the whole library has been reviewed — counts as a completed day.
    func markTodayComplete() {
        rollDayIfNeeded()
        data.completedDays.insert(data.dayKey)
        save()
    }

    // MARK: - Pending changes

    var pendingDeleteBytes: Int64 {
        data.pendingDeletes.reduce(0) { $0 + (data.pendingDeleteSizes[$1] ?? 0) }
    }

    var hasPendingChanges: Bool {
        !data.pendingDeletes.isEmpty || !data.pendingFavorites.isEmpty
    }

    /// Un-mark an item from deletion; it stays reviewed (= kept).
    func rescue(_ id: String) {
        data.pendingDeletes.removeAll { $0 == id }
        data.pendingDeleteSizes[id] = nil
        save()
    }

    func deletionsCommitted(_ ids: [String], bytes: Int64) {
        let done = Set(ids)
        data.pendingDeletes.removeAll { done.contains($0) }
        for id in ids { data.pendingDeleteSizes[id] = nil }
        data.totalDeleted += ids.count
        data.totalFreedBytes += bytes
        save()
    }

    func favoritesCommitted(_ ids: [String]) {
        let done = Set(ids)
        data.pendingFavorites.removeAll { done.contains($0) }
        data.totalFavorited += ids.count
        save()
    }

    /// Drops pending items that no longer exist in the library (deleted elsewhere).
    func dropMissingPending(existing: Set<String>) {
        let beforeD = data.pendingDeletes.count
        let beforeF = data.pendingFavorites.count
        data.pendingDeletes.removeAll { !existing.contains($0) }
        data.pendingFavorites.removeAll { !existing.contains($0) }
        data.pendingDeleteSizes = data.pendingDeleteSizes.filter { existing.contains($0.key) }
        if beforeD != data.pendingDeletes.count || beforeF != data.pendingFavorites.count { save() }
    }

    func resetProgress() {
        var fresh = ProgressData()
        fresh.onboarded = data.onboarded
        fresh.dailyGoal = data.dailyGoal
        fresh.reminderEnabled = data.reminderEnabled
        fresh.reminderHour = data.reminderHour
        fresh.reminderMinute = data.reminderMinute
        fresh.newestFirst = data.newestFirst
        data = fresh
        rollDayIfNeeded()
        save()
    }
}
