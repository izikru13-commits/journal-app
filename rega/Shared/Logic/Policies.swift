import Foundation

// MARK: - Escalating delay

enum DelayPolicy {
    /// Breathing countdown before an opening: base + step per earlier approved opening today, capped at max.
    static func seconds(approvedToday: Int, base: Int = 8, step: Int = 4, max maximum: Int = 60) -> Int {
        let raw = base + step * max(0, approvedToday)
        return min(max(raw, 0), max(maximum, 0))
    }

    static func seconds(approvedToday: Int, settings: RegaSettings) -> Int {
        seconds(
            approvedToday: approvedToday,
            base: settings.delayBaseSeconds,
            step: settings.delayStepSeconds,
            max: settings.delayMaxSeconds
        )
    }
}

// MARK: - Gate unlocks

enum UnlockMath {
    /// `DeviceActivitySchedule` throws `intervalTooShort` below this length.
    static let minimumScheduleMinutes = 15
    static let allowedMinutes = [1, 5, 10, 15]

    static func make(target: ShieldTarget, minutes: Int, now: Date) -> GateUnlock {
        GateUnlock(target: target, until: now.addingTimeInterval(TimeInterval(minutes * 60)), minutes: minutes)
    }

    static func active(_ unlocks: [GateUnlock], at now: Date) -> [GateUnlock] {
        unlocks.filter { $0.until > now }
    }

    static func expired(_ unlocks: [GateUnlock], at now: Date) -> [GateUnlock] {
        unlocks.filter { $0.until <= now }
    }

    /// Adds an unlock, replacing any existing one for the same target.
    static func merge(_ unlocks: [GateUnlock], with unlock: GateUnlock) -> [GateUnlock] {
        unlocks.filter { $0.target.key != unlock.target.key } + [unlock]
    }

    /// The re-shield schedule: it starts exactly when the opening expires and lasts the minimum
    /// 15 minutes, so the monitor's `intervalDidStart` fires at the right moment.
    static func relockWindow(for unlock: GateUnlock) -> DateInterval {
        DateInterval(start: unlock.until, duration: TimeInterval(minimumScheduleMinutes * 60))
    }

    static func nextExpiry(_ unlocks: [GateUnlock], after now: Date) -> Date? {
        active(unlocks, at: now).map(\.until).min()
    }
}

// MARK: - Attempt de-duplication

enum AttemptDeduper {
    /// The shield configuration can be requested several times per opening.
    static let shieldWindow: TimeInterval = 10
    /// The action extension only counts an attempt if the shield itself didn't recently.
    static let actionWindow: TimeInterval = 120

    static func shouldRecord(key: String, at date: Date, last: [String: Date], window: TimeInterval) -> Bool {
        guard let previous = last[key] else { return true }
        return date.timeIntervalSince(previous) >= window || date < previous
    }
}

// MARK: - Daily budget

enum BudgetMath {
    /// Threshold events that arrive this soon after monitoring started are ignored
    /// (reported to fire spuriously right after `startMonitoring` on some iOS versions).
    static let spuriousGuardSeconds: TimeInterval = 60

    static func warningMinutes(budget: Int) -> Int {
        max(1, Int((Double(budget) * 0.8).rounded(.down)))
    }

    static func limitMinutes(budget: Int) -> Int {
        max(1, budget)
    }

    static func isLikelySpurious(eventAt: Date, monitoringStartedAt: Date?) -> Bool {
        guard let start = monitoringStartedAt else { return false }
        let elapsed = eventAt.timeIntervalSince(start)
        return elapsed >= -1 && elapsed < spuriousGuardSeconds
    }

    static func remainingMinutes(used: Int, budget: Int) -> Int {
        max(0, budget - used)
    }

    static func fraction(used: Int, budget: Int) -> Double {
        guard budget > 0 else { return 1 }
        return min(1, max(0, Double(used) / Double(budget)))
    }

    static func isActive(state: BudgetState, settings: RegaSettings, now: Date, calendar: Calendar = .rega) -> Bool {
        guard settings.budgetEnabled else { return false }
        let today = DayKey.make(now, calendar: calendar)
        return state.exceededDay == today && state.dismissedDay != today
    }
}

// MARK: - Emergency exits

enum EmergencyExits {
    static let weeklyLimit = 3
    static let phrase = "אני בוחר לבזבז את הזמן שלי עכשיו"

    static func usesThisWeek(_ uses: [Date], now: Date, calendar: Calendar = .rega) -> Int {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else { return 0 }
        return uses.filter { $0 >= week.start && $0 < week.end }.count
    }

    static func remaining(_ uses: [Date], now: Date, calendar: Calendar = .rega) -> Int {
        max(0, weeklyLimit - usesThisWeek(uses, now: now, calendar: calendar))
    }

    static func nextReset(after now: Date, calendar: Calendar = .rega) -> Date? {
        calendar.dateInterval(of: .weekOfYear, for: now)?.end
    }

    /// Exact match; only surrounding whitespace is forgiven.
    static func matches(_ input: String) -> Bool {
        input.trimmingCharacters(in: .whitespacesAndNewlines) == phrase
    }

    /// Keeps only the last few weeks so the list never grows.
    static func pruned(_ uses: [Date], now: Date) -> [Date] {
        uses.filter { now.timeIntervalSince($0) < 35 * 86_400 }
    }
}

// MARK: - Lock schedules

enum LockHint {
    /// The lock's interval is starting now; evaluate it slightly ahead to absorb early callbacks.
    case starting
    /// The lock's interval just ended; treat it as off.
    case ending
}

struct ActiveLock: Equatable {
    var rule: LockRule
    var until: Date
}

struct ActiveProtection: Equatable {
    var locks: [ActiveLock] = []
    var manual: ManualSession?
    var budgetActive = false

    var isStrict: Bool { locks.contains { $0.rule.isStrict } || manual?.isStrict == true }
    var isLocked: Bool { !locks.isEmpty || manual != nil || budgetActive }
    var hasEndableLock: Bool { !locks.isEmpty || manual != nil }

    /// Latest end among the active hard locks (budget ends at midnight).
    var lockedUntil: Date? {
        (locks.map(\.until) + [manual?.end].compactMap { $0 }).max()
    }
}

enum LockSchedule {
    static let startTolerance: TimeInterval = 120

    /// The occurrence of `rule` that contains `date`, if any.
    static func activeOccurrence(of rule: LockRule, at date: Date, calendar: Calendar = .rega) -> DateInterval? {
        guard rule.isEnabled, rule.durationMinutes > 0 else { return nil }
        let today = calendar.startOfDay(for: date)
        for offset in [0, -1] {
            guard
                let day = calendar.date(byAdding: .day, value: offset, to: today),
                rule.weekdays.contains(calendar.component(.weekday, from: day)),
                let start = calendar.date(
                    bySettingHour: rule.startMinute / 60, minute: rule.startMinute % 60, second: 0, of: day)
            else { continue }
            let end = start.addingTimeInterval(TimeInterval(rule.durationMinutes * 60))
            if date >= start && date < end {
                return DateInterval(start: start, end: end)
            }
        }
        return nil
    }

    /// Next start of `rule` strictly after `date` (within the next 8 days).
    static func nextStart(of rule: LockRule, after date: Date, calendar: Calendar = .rega) -> Date? {
        guard rule.isEnabled, !rule.weekdays.isEmpty else { return nil }
        let today = calendar.startOfDay(for: date)
        for offset in 0...8 {
            guard
                let day = calendar.date(byAdding: .day, value: offset, to: today),
                rule.weekdays.contains(calendar.component(.weekday, from: day)),
                let start = calendar.date(
                    bySettingHour: rule.startMinute / 60, minute: rule.startMinute % 60, second: 0, of: day),
                start > date
            else { continue }
            return start
        }
        return nil
    }
}

enum ProtectionEvaluator {
    static func evaluate(
        rules: [LockRule],
        manual: ManualSession?,
        overrides: [LockOverride],
        budget: BudgetState,
        settings: RegaSettings,
        now: Date,
        hints: [UUID: LockHint] = [:],
        calendar: Calendar = .rega
    ) -> ActiveProtection {
        var result = ActiveProtection()
        for rule in rules where rule.isEnabled {
            let evaluationDate: Date
            switch hints[rule.id] {
            case .ending: continue
            case .starting: evaluationDate = now.addingTimeInterval(LockSchedule.startTolerance)
            case nil: evaluationDate = now
            }
            guard let occurrence = LockSchedule.activeOccurrence(of: rule, at: evaluationDate, calendar: calendar)
            else { continue }
            let overridden = overrides.contains { $0.lockID == rule.id && $0.until > now && $0.until >= occurrence.end }
            if !overridden {
                result.locks.append(ActiveLock(rule: rule, until: occurrence.end))
            }
        }
        if let manual, manual.start <= now, manual.end > now {
            result.manual = manual
        }
        result.budgetActive = BudgetMath.isActive(state: budget, settings: settings, now: now, calendar: calendar)
        return result
    }

    /// Overrides that end every active hard lock until its current occurrence is over.
    static func overridesEnding(_ protection: ActiveProtection) -> [LockOverride] {
        protection.locks.map { LockOverride(lockID: $0.rule.id, until: $0.until) }
    }
}

// MARK: - Protection guard

enum ProtectionGuard {
    /// Settings that weaken protection are frozen while a strict lock is active.
    static func canWeaken(_ protection: ActiveProtection) -> Bool {
        !protection.isStrict
    }

    /// True when `new` is at least as strong as `old` for a numeric limit where lower is stronger.
    static func isTightening(oldLimit: Int, newLimit: Int) -> Bool { newLimit <= oldLimit }
}

// MARK: - Known apps

enum KnownApps {
    private static let schemes: [String: String] = [
        "com.burbn.instagram": "instagram://",
        "com.google.ios.youtube": "youtube://",
        "com.zhiliaoapp.musically": "snssdk1233://",
        "com.atebits.Tweetie2": "twitter://",
        "com.facebook.Facebook": "fb://",
        "com.reddit.Reddit": "reddit://",
        "com.toyopagroup.picaboo": "snapchat://",
        "net.whatsapp.WhatsApp": "whatsapp://",
    ]

    static func urlScheme(forBundleID bundleID: String?) -> String? {
        guard let bundleID else { return nil }
        return schemes[bundleID]
    }
}
