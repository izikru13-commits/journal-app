import XCTest

private var calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.firstWeekday = 1
    calendar.timeZone = TimeZone(identifier: "Asia/Jerusalem")!
    return calendar
}()

private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ min: Int = 0, _ s: Int = 0) -> Date {
    calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min, second: s))!
}

final class DelayPolicyTests: XCTestCase {
    func testDefaultEscalation() {
        XCTAssertEqual(DelayPolicy.seconds(approvedToday: 0), 8)
        XCTAssertEqual(DelayPolicy.seconds(approvedToday: 1), 12)
        XCTAssertEqual(DelayPolicy.seconds(approvedToday: 5), 28)
    }

    func testCappedAtMaximum() {
        XCTAssertEqual(DelayPolicy.seconds(approvedToday: 13), 60)
        XCTAssertEqual(DelayPolicy.seconds(approvedToday: 100), 60)
    }

    func testNegativeCountTreatedAsZero() {
        XCTAssertEqual(DelayPolicy.seconds(approvedToday: -3), 8)
    }

    func testCustomSettings() {
        var settings = RegaSettings()
        settings.delayBaseSeconds = 5
        settings.delayStepSeconds = 10
        settings.delayMaxSeconds = 30
        XCTAssertEqual(DelayPolicy.seconds(approvedToday: 0, settings: settings), 5)
        XCTAssertEqual(DelayPolicy.seconds(approvedToday: 2, settings: settings), 25)
        XCTAssertEqual(DelayPolicy.seconds(approvedToday: 3, settings: settings), 30)
    }

    func testBaseAboveMaxIsCapped() {
        XCTAssertEqual(DelayPolicy.seconds(approvedToday: 0, base: 90, step: 4, max: 60), 60)
    }
}

final class UnlockMathTests: XCTestCase {
    private let target = ShieldTarget(kind: .application, tokenData: Data([1, 2, 3]))
    private let other = ShieldTarget(kind: .application, tokenData: Data([9]))

    func testUnlockExpiresAfterMinutes() {
        let now = date(2026, 1, 1, 10)
        let unlock = UnlockMath.make(target: target, minutes: 5, now: now)
        XCTAssertEqual(unlock.until, now.addingTimeInterval(300))
        XCTAssertEqual(UnlockMath.active([unlock], at: now.addingTimeInterval(299)).count, 1)
        XCTAssertTrue(UnlockMath.active([unlock], at: now.addingTimeInterval(300)).isEmpty)
        XCTAssertEqual(UnlockMath.expired([unlock], at: now.addingTimeInterval(301)).count, 1)
    }

    func testRelockWindowStartsAtExpiryAndLastsFifteenMinutes() {
        let now = date(2026, 1, 1, 23, 58)
        for minutes in UnlockMath.allowedMinutes {
            let unlock = UnlockMath.make(target: target, minutes: minutes, now: now)
            let window = UnlockMath.relockWindow(for: unlock)
            XCTAssertEqual(window.start, unlock.until)
            XCTAssertGreaterThanOrEqual(window.duration, 15 * 60)
        }
    }

    func testMergeReplacesSameTarget() {
        let now = date(2026, 1, 1)
        let first = UnlockMath.make(target: target, minutes: 1, now: now)
        let second = UnlockMath.make(target: target, minutes: 10, now: now)
        let third = UnlockMath.make(target: other, minutes: 5, now: now)
        let merged = UnlockMath.merge(UnlockMath.merge([first, third], with: second), with: second)
        XCTAssertEqual(merged.count, 2)
        XCTAssertEqual(merged.first { $0.target == target }?.minutes, 10)
    }

    func testNextExpiry() {
        let now = date(2026, 1, 1)
        let a = UnlockMath.make(target: target, minutes: 10, now: now)
        let b = UnlockMath.make(target: other, minutes: 1, now: now)
        XCTAssertEqual(UnlockMath.nextExpiry([a, b], after: now), b.until)
        XCTAssertNil(UnlockMath.nextExpiry([a, b], after: now.addingTimeInterval(3600)))
    }

    func testTargetKeysAreStableAndDistinct() {
        XCTAssertEqual(target.key, ShieldTarget(kind: .application, tokenData: Data([1, 2, 3])).key)
        XCTAssertNotEqual(target.key, other.key)
        XCTAssertNotEqual(target.key, ShieldTarget(kind: .category, tokenData: Data([1, 2, 3])).key)
        XCTAssertTrue(target.key.hasPrefix("a"))
        XCTAssertEqual(target.key.count, 17)
    }

    func testPendingRequestFreshness() {
        let now = date(2026, 1, 1)
        let request = PendingRequest(id: UUID(), target: target, createdAt: now)
        XCTAssertTrue(request.isFresh(at: now.addingTimeInterval(60)))
        XCTAssertFalse(request.isFresh(at: now.addingTimeInterval(16 * 60)))
    }
}

final class BudgetMathTests: XCTestCase {
    func testThresholds() {
        XCTAssertEqual(BudgetMath.warningMinutes(budget: 30), 24)
        XCTAssertEqual(BudgetMath.warningMinutes(budget: 1), 1)
        XCTAssertEqual(BudgetMath.warningMinutes(budget: 45), 36)
        XCTAssertEqual(BudgetMath.limitMinutes(budget: 30), 30)
        XCTAssertEqual(BudgetMath.limitMinutes(budget: 0), 1)
    }

    func testRemainingAndFraction() {
        XCTAssertEqual(BudgetMath.remainingMinutes(used: 10, budget: 30), 20)
        XCTAssertEqual(BudgetMath.remainingMinutes(used: 40, budget: 30), 0)
        XCTAssertEqual(BudgetMath.fraction(used: 15, budget: 30), 0.5, accuracy: 0.0001)
        XCTAssertEqual(BudgetMath.fraction(used: 45, budget: 30), 1)
        XCTAssertEqual(BudgetMath.fraction(used: 5, budget: 0), 1)
    }

    func testSpuriousGuard() {
        let start = date(2026, 1, 1, 9)
        XCTAssertTrue(BudgetMath.isLikelySpurious(eventAt: start.addingTimeInterval(2), monitoringStartedAt: start))
        XCTAssertTrue(BudgetMath.isLikelySpurious(eventAt: start.addingTimeInterval(59), monitoringStartedAt: start))
        XCTAssertFalse(BudgetMath.isLikelySpurious(eventAt: start.addingTimeInterval(61), monitoringStartedAt: start))
        XCTAssertFalse(BudgetMath.isLikelySpurious(eventAt: start, monitoringStartedAt: nil))
    }

    func testBudgetActiveOnlyOnExceededDayAndNotDismissed() {
        var settings = RegaSettings()
        settings.budgetEnabled = true
        let now = date(2026, 3, 4, 15)
        var state = BudgetState()
        state.exceededDay = DayKey.make(now, calendar: calendar)
        XCTAssertTrue(BudgetMath.isActive(state: state, settings: settings, now: now, calendar: calendar))
        XCTAssertFalse(BudgetMath.isActive(state: state, settings: settings, now: date(2026, 3, 5, 0, 1), calendar: calendar))
        state.dismissedDay = state.exceededDay
        XCTAssertFalse(BudgetMath.isActive(state: state, settings: settings, now: now, calendar: calendar))
        state.dismissedDay = nil
        settings.budgetEnabled = false
        XCTAssertFalse(BudgetMath.isActive(state: state, settings: settings, now: now, calendar: calendar))
    }
}

final class EmergencyExitTests: XCTestCase {
    // 2026-03-01 is a Sunday.
    func testCountsOnlyCurrentSundayBasedWeek() {
        let wednesday = date(2026, 3, 4, 12)
        let uses = [
            date(2026, 2, 28, 23, 59), // previous Saturday
            date(2026, 3, 1, 0, 1),    // Sunday
            date(2026, 3, 3, 10),      // Tuesday
        ]
        XCTAssertEqual(EmergencyExits.usesThisWeek(uses, now: wednesday, calendar: calendar), 2)
        XCTAssertEqual(EmergencyExits.remaining(uses, now: wednesday, calendar: calendar), 1)
    }

    func testResetsOnSunday() {
        let uses = [date(2026, 3, 2), date(2026, 3, 3), date(2026, 3, 7, 22)]
        XCTAssertEqual(EmergencyExits.remaining(uses, now: date(2026, 3, 7, 23), calendar: calendar), 0)
        XCTAssertEqual(EmergencyExits.remaining(uses, now: date(2026, 3, 8, 0, 0, 1), calendar: calendar), 3)
        XCTAssertEqual(EmergencyExits.nextReset(after: date(2026, 3, 4), calendar: calendar), date(2026, 3, 8, 0, 0))
    }

    func testRemainingNeverNegative() {
        let now = date(2026, 3, 4)
        let uses = Array(repeating: now, count: 5)
        XCTAssertEqual(EmergencyExits.remaining(uses, now: now, calendar: calendar), 0)
    }

    func testPhraseMustMatchExactly() {
        XCTAssertTrue(EmergencyExits.matches("אני בוחר לבזבז את הזמן שלי עכשיו"))
        XCTAssertTrue(EmergencyExits.matches("  אני בוחר לבזבז את הזמן שלי עכשיו\n"))
        XCTAssertFalse(EmergencyExits.matches("אני בוחר לבזבז את הזמן שלי"))
        XCTAssertFalse(EmergencyExits.matches("אני בוחר  לבזבז את הזמן שלי עכשיו"))
        XCTAssertFalse(EmergencyExits.matches(""))
    }

    func testPruneKeepsRecentUses() {
        let now = date(2026, 3, 4)
        let uses = [date(2026, 1, 1), date(2026, 3, 1)]
        XCTAssertEqual(EmergencyExits.pruned(uses, now: now), [date(2026, 3, 1)])
    }
}

final class LockScheduleTests: XCTestCase {
    private func rule(start: Int, duration: Int, days: Set<Int> = Set(1...7), strict: Bool = true) -> LockRule {
        LockRule(id: UUID(), name: "t", kind: .custom, startMinute: start, durationMinutes: duration,
                 weekdays: days, isStrict: strict, isEnabled: true, usesDistractions: true)
    }

    func testOvernightLockSpansMidnight() {
        let sleep = rule(start: 23 * 60, duration: 8 * 60)
        XCTAssertNotNil(LockSchedule.activeOccurrence(of: sleep, at: date(2026, 3, 4, 23, 30), calendar: calendar))
        XCTAssertNotNil(LockSchedule.activeOccurrence(of: sleep, at: date(2026, 3, 5, 6, 59), calendar: calendar))
        XCTAssertNil(LockSchedule.activeOccurrence(of: sleep, at: date(2026, 3, 5, 7, 0), calendar: calendar))
        XCTAssertNil(LockSchedule.activeOccurrence(of: sleep, at: date(2026, 3, 4, 22, 59), calendar: calendar))
        XCTAssertEqual(LockSchedule.activeOccurrence(of: sleep, at: date(2026, 3, 5, 2), calendar: calendar)?.end, date(2026, 3, 5, 7))
    }

    func testOvernightLockBelongsToStartDay() {
        // Sunday night only (weekday 1). Monday 02:00 is still inside Sunday's occurrence.
        let sleep = rule(start: 23 * 60, duration: 8 * 60, days: [1])
        XCTAssertNotNil(LockSchedule.activeOccurrence(of: sleep, at: date(2026, 3, 2, 2), calendar: calendar))
        XCTAssertNil(LockSchedule.activeOccurrence(of: sleep, at: date(2026, 3, 2, 23, 30), calendar: calendar))
    }

    func testDisabledLockNeverActive() {
        var lock = rule(start: 0, duration: 23 * 60)
        lock.isEnabled = false
        XCTAssertNil(LockSchedule.activeOccurrence(of: lock, at: date(2026, 3, 4, 10), calendar: calendar))
    }

    func testDurationHelperCrossesMidnightAndClamps() {
        XCTAssertEqual(LockRule.duration(from: 23 * 60, to: 7 * 60), 8 * 60)
        XCTAssertEqual(LockRule.duration(from: 9 * 60, to: 9 * 60 + 5), 15)
        XCTAssertEqual(LockRule.duration(from: 9 * 60, to: 9 * 60), LockRule.maximumDuration)
        XCTAssertEqual(LockRule.sleep().endMinute, 7 * 60)
    }

    func testNextStart() {
        let lock = rule(start: 9 * 60, duration: 60, days: [2]) // Mondays
        XCTAssertEqual(LockSchedule.nextStart(of: lock, after: date(2026, 3, 4), calendar: calendar), date(2026, 3, 9, 9))
    }

    func testStartingHintAbsorbsEarlyCallback() {
        let lock = rule(start: 23 * 60, duration: 60)
        let early = date(2026, 3, 4, 22, 59, 59)
        let settings = RegaSettings()
        let plain = ProtectionEvaluator.evaluate(rules: [lock], manual: nil, overrides: [], budget: BudgetState(), settings: settings, now: early, calendar: calendar)
        XCTAssertTrue(plain.locks.isEmpty)
        let hinted = ProtectionEvaluator.evaluate(rules: [lock], manual: nil, overrides: [], budget: BudgetState(), settings: settings, now: early, hints: [lock.id: .starting], calendar: calendar)
        XCTAssertEqual(hinted.locks.count, 1)
        XCTAssertTrue(hinted.isStrict)
    }

    func testEndingHintTurnsLockOff() {
        let lock = rule(start: 23 * 60, duration: 60)
        let late = date(2026, 3, 4, 23, 59, 59)
        let result = ProtectionEvaluator.evaluate(rules: [lock], manual: nil, overrides: [], budget: BudgetState(), settings: RegaSettings(), now: late, hints: [lock.id: .ending], calendar: calendar)
        XCTAssertTrue(result.locks.isEmpty)
    }

    func testOverrideEndsOnlyCurrentOccurrence() {
        let lock = rule(start: 23 * 60, duration: 8 * 60)
        let tonight = date(2026, 3, 4, 23, 30)
        let active = ProtectionEvaluator.evaluate(rules: [lock], manual: nil, overrides: [], budget: BudgetState(), settings: RegaSettings(), now: tonight, calendar: calendar)
        let overrides = ProtectionEvaluator.overridesEnding(active)
        XCTAssertEqual(overrides.first?.until, date(2026, 3, 5, 7))

        let afterKey = ProtectionEvaluator.evaluate(rules: [lock], manual: nil, overrides: overrides, budget: BudgetState(), settings: RegaSettings(), now: tonight.addingTimeInterval(60), calendar: calendar)
        XCTAssertTrue(afterKey.locks.isEmpty)
        XCTAssertFalse(afterKey.isStrict)

        let tomorrow = ProtectionEvaluator.evaluate(rules: [lock], manual: nil, overrides: overrides, budget: BudgetState(), settings: RegaSettings(), now: date(2026, 3, 5, 23, 30), calendar: calendar)
        XCTAssertEqual(tomorrow.locks.count, 1)
    }

    func testManualSessionWindow() {
        let now = date(2026, 3, 4, 12)
        let session = ManualSession(id: UUID(), start: now, end: now.addingTimeInterval(1800), isStrict: true)
        let during = ProtectionEvaluator.evaluate(rules: [], manual: session, overrides: [], budget: BudgetState(), settings: RegaSettings(), now: now.addingTimeInterval(60), calendar: calendar)
        XCTAssertTrue(during.isStrict)
        XCTAssertEqual(during.lockedUntil, session.end)
        let after = ProtectionEvaluator.evaluate(rules: [], manual: session, overrides: [], budget: BudgetState(), settings: RegaSettings(), now: session.end, calendar: calendar)
        XCTAssertFalse(after.isLocked)
    }

    func testBudgetLockIsNeverStrict() {
        var settings = RegaSettings()
        settings.budgetEnabled = true
        let now = date(2026, 3, 4, 15)
        var budget = BudgetState()
        budget.exceededDay = DayKey.make(now, calendar: calendar)
        let result = ProtectionEvaluator.evaluate(rules: [], manual: nil, overrides: [], budget: budget, settings: settings, now: now, calendar: calendar)
        XCTAssertTrue(result.budgetActive)
        XCTAssertFalse(result.isStrict)
        XCTAssertTrue(ProtectionGuard.canWeaken(result))
    }
}

final class StatsTests: XCTestCase {
    func testDismissRate() {
        XCTAssertNil(StatsMath.dismissRate(attempts: 0, dismissed: 0, approved: 0))
        XCTAssertEqual(StatsMath.dismissRate(attempts: 10, dismissed: 5, approved: 2)!, 0.8, accuracy: 0.0001)
        // Unrecorded attempts: the denominator is at least the known decisions.
        XCTAssertEqual(StatsMath.dismissRate(attempts: 1, dismissed: 3, approved: 1)!, 0.75, accuracy: 0.0001)
    }

    func testStreakCountsDaysWithinGoal() {
        let today = date(2026, 3, 10)
        var counters: [String: DayCounters] = [:]
        for offset in 0..<5 {
            let day = calendar.date(byAdding: .day, value: -offset, to: today)!
            counters[DayKey.make(day, calendar: calendar)] = DayCounters(attempts: 5, dismissed: 3, approved: 2)
        }
        let bad = calendar.date(byAdding: .day, value: -5, to: today)!
        counters[DayKey.make(bad, calendar: calendar)] = DayCounters(attempts: 9, approved: 8)
        XCTAssertEqual(StatsMath.streak(counters: counters, goal: 3, today: today, since: date(2026, 1, 1), calendar: calendar), 5)
        XCTAssertEqual(StatsMath.streak(counters: counters, goal: 1, today: today, since: date(2026, 1, 1), calendar: calendar), 0)
    }

    func testStreakStopsAtInstallDay() {
        let today = date(2026, 3, 10)
        XCTAssertEqual(StatsMath.streak(counters: [:], goal: 3, today: today, since: date(2026, 3, 8), calendar: calendar), 3)
    }

    func testLastDaysAndTotal() {
        let today = date(2026, 3, 10)
        let counters = [DayKey.make(today, calendar: calendar): DayCounters(attempts: 4, dismissed: 2, approved: 1, approvedMinutes: 5)]
        let days = StatsMath.lastDays(7, counters: counters, today: today, calendar: calendar)
        XCTAssertEqual(days.count, 7)
        XCTAssertEqual(days.last?.counters.attempts, 4)
        XCTAssertEqual(StatsMath.total(days).approvedMinutes, 5)
    }

    func testTopIntention() {
        let now = date(2026, 3, 10)
        let events = [
            RegaEvent(date: now, kind: .approved, intention: .habit),
            RegaEvent(date: now, kind: .approved, intention: .habit),
            RegaEvent(date: now, kind: .approved, intention: .work),
            RegaEvent(date: now, kind: .dismissed, intention: .work),
            RegaEvent(date: date(2026, 1, 1), kind: .approved, intention: .work),
        ]
        XCTAssertEqual(StatsMath.topIntention(events, since: date(2026, 3, 1)), .habit)
        XCTAssertNil(StatsMath.topIntention([], since: now))
    }
}

final class EventLogTests: XCTestCase {
    private var store: SharedStore!
    private let suite = "rega.tests.eventlog"

    override func setUp() {
        super.setUp()
        UserDefaults().removePersistentDomain(forName: suite)
        store = SharedStore(defaults: UserDefaults(suiteName: suite)!)
    }

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: suite)
        super.tearDown()
    }

    func testRecordUpdatesCounters() {
        let now = date(2026, 3, 10, 9)
        EventLog.record(RegaEvent(date: now, kind: .attempt), store: store, calendar: calendar)
        EventLog.record(RegaEvent(date: now, kind: .dismissed), store: store, calendar: calendar)
        EventLog.record(RegaEvent(date: now, kind: .approved, intention: .work, minutes: 10), store: store, calendar: calendar)
        let day = store.counters[DayKey.make(now, calendar: calendar)]
        XCTAssertEqual(day, DayCounters(attempts: 1, dismissed: 1, approved: 1, approvedMinutes: 10))
        XCTAssertEqual(store.events.count, 3)
    }

    func testAttemptDeduplication() {
        let now = date(2026, 3, 10, 9)
        XCTAssertTrue(EventLog.recordAttempt(targetKey: "a1", at: now, window: 10, source: "shield", store: store))
        XCTAssertFalse(EventLog.recordAttempt(targetKey: "a1", at: now.addingTimeInterval(5), window: 10, source: "shield", store: store))
        XCTAssertTrue(EventLog.recordAttempt(targetKey: "a2", at: now.addingTimeInterval(5), window: 10, source: "shield", store: store))
        XCTAssertTrue(EventLog.recordAttempt(targetKey: "a1", at: now.addingTimeInterval(11), window: 10, source: "shield", store: store))
        // The action extension uses a longer window so it doesn't double count the shield's attempt.
        XCTAssertFalse(EventLog.recordAttempt(targetKey: "a1", at: now.addingTimeInterval(60), window: AttemptDeduper.actionWindow, source: "action", store: store))
        XCTAssertEqual(store.counters[DayKey.make(now, calendar: .rega)]?.attempts, 3)
    }

    func testOldEventsArePruned() {
        EventLog.record(RegaEvent(date: date(2025, 1, 1), kind: .attempt), store: store, calendar: calendar)
        EventLog.record(RegaEvent(date: date(2026, 3, 10), kind: .attempt), store: store, calendar: calendar)
        XCTAssertEqual(store.events.count, 1)
    }

    func testSettingsDecodeWithMissingKeys() throws {
        let data = Data(#"{"delayBaseSeconds": 12}"#.utf8)
        let settings = try JSONDecoder().decode(RegaSettings.self, from: data)
        XCTAssertEqual(settings.delayBaseSeconds, 12)
        XCTAssertEqual(settings.delayMaxSeconds, 60)
        XCTAssertTrue(settings.gateEnabled)
    }
}

final class KeyAndFormattingTests: XCTestCase {
    func testKeyPayloadRoundTrip() {
        let secret = KeyCodec.newSecret()
        XCTAssertGreaterThanOrEqual(secret.count, 30)
        XCTAssertNotEqual(secret, KeyCodec.newSecret())
        XCTAssertTrue(KeyCodec.matches(scanned: KeyCodec.payload(for: secret), secret: secret))
        XCTAssertFalse(KeyCodec.matches(scanned: KeyCodec.payload(for: "other"), secret: secret))
        XCTAssertFalse(KeyCodec.matches(scanned: secret, secret: secret))
        XCTAssertFalse(KeyCodec.matches(scanned: "anything", secret: nil))
    }

    func testKnownAppSchemes() {
        XCTAssertEqual(KnownApps.urlScheme(forBundleID: "com.burbn.instagram"), "instagram://")
        XCTAssertNil(KnownApps.urlScheme(forBundleID: "com.example.unknown"))
        XCTAssertNil(KnownApps.urlScheme(forBundleID: nil))
    }

    func testDurationText() {
        XCTAssertEqual(DurationText.short(3 * 3600 + 12 * 60), "3 ש׳ 12 ד׳")
        XCTAssertEqual(DurationText.short(45 * 60), "45 ד׳")
        XCTAssertEqual(DurationText.short(30), "פחות מדקה")
        XCTAssertEqual(DurationText.clock(23 * 60 + 5), "23:05")
        XCTAssertEqual(DurationText.weekdays(Set(1...7)), "כל יום")
        XCTAssertEqual(DurationText.weekdays([1, 3]), "א׳ ג׳")
    }
}
