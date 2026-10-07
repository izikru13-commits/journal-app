import XCTest
@testable import SwipeClean

final class ProgressStoreTests: XCTestCase {
    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("progress-\(UUID().uuidString).json")
    }

    @MainActor
    private func makeStore(goal: Int = 50) -> ProgressStore {
        let store = ProgressStore(fileURL: tempURL(), startFresh: true)
        store.update { $0.dailyGoal = goal }
        return store
    }

    private func dayKey(_ daysAgo: Int) -> String {
        let d = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        return ProgressStore.key(for: d)
    }

    // MARK: - Decisions

    @MainActor
    func testRecordKeepDeleteFavorite() {
        let store = makeStore()
        store.record(.keep, id: "a", size: 100)
        store.record(.delete, id: "b", size: 2_000_000)
        store.record(.delete, id: "c", size: 1_000_000)
        store.record(.favorite, id: "d", size: 50)

        XCTAssertEqual(store.data.reviewedIDs, ["a", "b", "c", "d"])
        XCTAssertEqual(store.data.totalReviewed, 4)
        XCTAssertEqual(store.data.todayReviewed, 4)
        XCTAssertEqual(store.data.pendingDeletes, ["b", "c"])
        XCTAssertEqual(store.pendingDeleteBytes, 3_000_000)
        XCTAssertEqual(store.data.pendingFavorites, ["d"])
        XCTAssertTrue(store.hasPendingChanges)
    }

    @MainActor
    func testUndoRevertsDecision() {
        let store = makeStore()
        store.record(.delete, id: "b", size: 500)
        store.record(.favorite, id: "f", size: 10)
        store.undo(.favorite, id: "f")
        store.undo(.delete, id: "b")

        XCTAssertTrue(store.data.reviewedIDs.isEmpty)
        XCTAssertEqual(store.data.totalReviewed, 0)
        XCTAssertEqual(store.data.todayReviewed, 0)
        XCTAssertTrue(store.data.pendingDeletes.isEmpty)
        XCTAssertTrue(store.data.pendingFavorites.isEmpty)
        XCTAssertEqual(store.pendingDeleteBytes, 0)
        XCTAssertFalse(store.hasPendingChanges)
    }

    @MainActor
    func testReachingDailyGoalCompletesDay() {
        let store = makeStore(goal: 3)
        store.record(.keep, id: "1", size: 0)
        store.record(.keep, id: "2", size: 0)
        XCTAssertFalse(store.todayDone)
        store.record(.keep, id: "3", size: 0)
        XCTAssertTrue(store.todayDone)
        XCTAssertEqual(store.streak, 1)

        store.undo(.keep, id: "3")
        XCTAssertFalse(store.todayDone)
        XCTAssertEqual(store.streak, 0)
    }

    @MainActor
    func testMarkTodayComplete() {
        let store = makeStore()
        store.markTodayComplete()
        XCTAssertTrue(store.todayDone)
    }

    // MARK: - Streak

    @MainActor
    func testStreakCountsConsecutiveDaysIncludingToday() {
        let store = makeStore()
        store.update { $0.completedDays = [dayKey(0), dayKey(1), dayKey(2), dayKey(4)] }
        XCTAssertEqual(store.streak, 3)
    }

    @MainActor
    func testStreakSurvivesUntilTodayIsDone() {
        let store = makeStore()
        store.update { $0.completedDays = [dayKey(1), dayKey(2)] }
        XCTAssertEqual(store.streak, 2, "today not done yet should not break the streak")
        store.update { $0.completedDays = [dayKey(2), dayKey(3)] }
        XCTAssertEqual(store.streak, 0, "missing yesterday breaks the streak")
    }

    @MainActor
    func testLastSevenDays() {
        let store = makeStore()
        store.update { $0.completedDays = [dayKey(0), dayKey(6)] }
        let days = store.lastSevenDays
        XCTAssertEqual(days.count, 7)
        XCTAssertTrue(days.last!.isToday)
        XCTAssertTrue(days.last!.done)
        XCTAssertTrue(days.first!.done)
        XCTAssertEqual(days.filter(\.done).count, 2)
    }

    // MARK: - Pending changes

    @MainActor
    func testRescueKeepsItemReviewed() {
        let store = makeStore()
        store.record(.delete, id: "x", size: 900)
        store.rescue("x")
        XCTAssertTrue(store.data.pendingDeletes.isEmpty)
        XCTAssertEqual(store.pendingDeleteBytes, 0)
        XCTAssertTrue(store.data.reviewedIDs.contains("x"), "rescued items count as kept, not re-shown")
    }

    @MainActor
    func testCommittingDeletionsUpdatesTotals() {
        let store = makeStore()
        store.record(.delete, id: "a", size: 1_500_000)
        store.record(.delete, id: "b", size: 900_000)
        store.deletionsCommitted(["a", "b"], bytes: store.pendingDeleteBytes)
        XCTAssertEqual(store.data.totalDeleted, 2)
        XCTAssertEqual(store.data.totalFreedBytes, 2_400_000)
        XCTAssertTrue(store.data.pendingDeletes.isEmpty)
        XCTAssertTrue(store.data.pendingDeleteSizes.isEmpty)
    }

    @MainActor
    func testCommittingFavorites() {
        let store = makeStore()
        store.record(.favorite, id: "a", size: 0)
        store.favoritesCommitted(["a"])
        XCTAssertEqual(store.data.totalFavorited, 1)
        XCTAssertTrue(store.data.pendingFavorites.isEmpty)
    }

    @MainActor
    func testDropMissingPending() {
        let store = makeStore()
        store.record(.delete, id: "gone", size: 10)
        store.record(.delete, id: "here", size: 20)
        store.record(.favorite, id: "goneFav", size: 0)
        store.dropMissingPending(existing: ["here"])
        XCTAssertEqual(store.data.pendingDeletes, ["here"])
        XCTAssertEqual(store.pendingDeleteBytes, 20)
        XCTAssertTrue(store.data.pendingFavorites.isEmpty)
    }

    // MARK: - Persistence

    @MainActor
    func testProgressPersistsAcrossLaunches() {
        let url = tempURL()
        let first = ProgressStore(fileURL: url, startFresh: true)
        first.record(.keep, id: "a", size: 0)
        first.record(.delete, id: "b", size: 42)
        first.update { $0.dailyGoal = 20 }
        first.waitForSave()

        let second = ProgressStore(fileURL: url)
        XCTAssertEqual(second.data.reviewedIDs, ["a", "b"])
        XCTAssertEqual(second.data.pendingDeletes, ["b"])
        XCTAssertEqual(second.pendingDeleteBytes, 42)
        XCTAssertEqual(second.data.dailyGoal, 20)
    }

    @MainActor
    func testDecodingIsTolerantToMissingFields() throws {
        let url = tempURL()
        try #"{"dailyGoal": 30, "reviewedIDs": ["q"]}"#.data(using: .utf8)!.write(to: url)
        let store = ProgressStore(fileURL: url)
        XCTAssertEqual(store.data.dailyGoal, 30)
        XCTAssertEqual(store.data.reviewedIDs, ["q"])
        XCTAssertTrue(store.data.reminderEnabled)
        XCTAssertEqual(store.data.totalDeleted, 0)
    }

    @MainActor
    func testCorruptFileStartsFresh() throws {
        let url = tempURL()
        try Data("not json".utf8).write(to: url)
        let store = ProgressStore(fileURL: url)
        XCTAssertTrue(store.data.reviewedIDs.isEmpty)
        XCTAssertEqual(store.data.dailyGoal, 50)
    }

    @MainActor
    func testResetKeepsSettings() {
        let store = makeStore(goal: 100)
        store.update { $0.onboarded = true; $0.reminderHour = 9; $0.newestFirst = true }
        store.record(.delete, id: "a", size: 5)
        store.resetProgress()
        XCTAssertTrue(store.data.reviewedIDs.isEmpty)
        XCTAssertTrue(store.data.pendingDeletes.isEmpty)
        XCTAssertEqual(store.data.dailyGoal, 100)
        XCTAssertEqual(store.data.reminderHour, 9)
        XCTAssertTrue(store.data.newestFirst)
        XCTAssertTrue(store.data.onboarded)
    }
}

final class FormatTests: XCTestCase {
    func testBytes() {
        XCTAssertEqual(Format.bytes(2_400_000_000), "2.4GB")
        XCTAssertEqual(Format.bytes(3_400_000), "3.4MB")
        XCTAssertEqual(Format.bytes(24_900_000), "24.9MB")
        XCTAssertEqual(Format.bytes(512_000), "512KB")
        XCTAssertEqual(Format.bytes(12), "12B")
    }

    func testNumberAndDuration() {
        XCTAssertEqual(Format.number(12904), "12,904")
        XCTAssertEqual(Format.duration(75), "1:15")
        XCTAssertEqual(Format.duration(9.6), "0:10")
    }

    func testHebrewDate() {
        var c = DateComponents()
        c.year = 2023; c.month = 7; c.day = 22; c.hour = 12
        let date = Calendar(identifier: .gregorian).date(from: c)!
        XCTAssertEqual(Format.date(date), "22 ביולי 2023")
        XCTAssertEqual(Format.date(nil), "")
    }
}
