import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

extension DeviceActivityName {
    static let manual = Self("rega.manual")
    static let budget = Self("rega.budget")
    static func lock(_ id: UUID) -> Self { Self("rega.lock.\(id.uuidString)") }
    static func relock(_ targetKey: String) -> Self { Self("rega.relock.\(targetKey)") }
}

extension DeviceActivityEvent.Name {
    static let budgetWarning = Self("rega.budget.warning")
    static let budgetLimit = Self("rega.budget.limit")
}

/// Parsed form of our activity names, used by the monitor extension.
enum RegaActivity: Equatable {
    case lock(UUID)
    case manual
    case budget
    case relock(String)
    case unknown

    init(_ name: DeviceActivityName) {
        let raw = name.rawValue
        if raw == DeviceActivityName.manual.rawValue {
            self = .manual
        } else if raw == DeviceActivityName.budget.rawValue {
            self = .budget
        } else if raw.hasPrefix("rega.lock."), let id = UUID(uuidString: String(raw.dropFirst("rega.lock.".count))) {
            self = .lock(id)
        } else if raw.hasPrefix("rega.relock.") {
            self = .relock(String(raw.dropFirst("rega.relock.".count)))
        } else {
            self = .unknown
        }
    }
}

enum ActivityScheduler {
    private static var center: DeviceActivityCenter { DeviceActivityCenter() }

    private static func components(_ date: Date, calendar: Calendar = .rega) -> DateComponents {
        calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
    }

    /// One daily repeating activity per enabled lock; weekdays are checked in `reconcile`.
    @discardableResult
    static func syncLocks(_ rules: [LockRule]) -> [Error] {
        let center = center
        let wanted = Set(rules.filter(\.isEnabled).map { DeviceActivityName.lock($0.id) })
        let stale = center.activities.filter { $0.rawValue.hasPrefix("rega.lock.") && !wanted.contains($0) }
        if !stale.isEmpty { center.stopMonitoring(stale) }

        var errors: [Error] = []
        for rule in rules where rule.isEnabled {
            let duration = min(max(rule.durationMinutes, LockRule.minimumDuration), LockRule.maximumDuration)
            let end = (rule.startMinute + duration) % (24 * 60)
            let schedule = DeviceActivitySchedule(
                intervalStart: DateComponents(hour: rule.startMinute / 60, minute: rule.startMinute % 60),
                intervalEnd: DateComponents(hour: end / 60, minute: end % 60),
                repeats: true
            )
            do {
                center.stopMonitoring([.lock(rule.id)])
                try center.startMonitoring(.lock(rule.id), during: schedule)
            } catch {
                errors.append(error)
            }
        }
        return errors
    }

    /// Re-shield timer: an activity that starts exactly when the opening expires and lasts
    /// the minimum 15 minutes. `intervalDidStart` re-applies the shield.
    static func scheduleRelock(for unlock: GateUnlock) throws {
        let window = UnlockMath.relockWindow(for: unlock)
        let schedule = DeviceActivitySchedule(
            intervalStart: components(window.start),
            intervalEnd: components(window.end),
            repeats: false
        )
        let center = center
        let name = DeviceActivityName.relock(unlock.target.key)
        center.stopMonitoring([name])
        try center.startMonitoring(name, during: schedule)
    }

    /// Stops relock activities whose opening is no longer active (the shield is already back).
    static func cleanupRelocks(activeUnlocks: [GateUnlock]) {
        let center = center
        let live = Set(activeUnlocks.map { DeviceActivityName.relock($0.target.key) })
        let stale = center.activities.filter { $0.rawValue.hasPrefix("rega.relock.") && !live.contains($0) }
        if !stale.isEmpty { center.stopMonitoring(stale) }
    }

    static func startManual(_ session: ManualSession, now: Date = Date()) throws {
        let start = min(now, session.start)
        let end = max(session.end, start.addingTimeInterval(TimeInterval(UnlockMath.minimumScheduleMinutes * 60)))
        let schedule = DeviceActivitySchedule(
            intervalStart: components(start),
            intervalEnd: components(end),
            repeats: false
        )
        let center = center
        center.stopMonitoring([.manual])
        try center.startMonitoring(.manual, during: schedule)
    }

    static func stopManual() {
        center.stopMonitoring([.manual])
    }

    /// Daily 00:00–23:59 activity with threshold events at 80 % and 100 % of the budget.
    static func syncBudget(settings: RegaSettings, store: SharedStore = .shared, now: Date = Date()) throws {
        let center = center
        center.stopMonitoring([.budget])
        let selection = store.distractions
        guard settings.budgetEnabled, !TokenSets(selection).isEmpty else { return }

        func event(minutes: Int) -> DeviceActivityEvent {
            DeviceActivityEvent(
                applications: selection.applicationTokens,
                categories: selection.categoryTokens,
                webDomains: selection.webDomainTokens,
                threshold: DateComponents(hour: minutes / 60, minute: minutes % 60)
            )
        }

        var state = store.budget
        state.monitoringStartedAt = now
        store.budget = state

        try center.startMonitoring(
            .budget,
            during: DeviceActivitySchedule(
                intervalStart: DateComponents(hour: 0, minute: 0),
                intervalEnd: DateComponents(hour: 23, minute: 59),
                repeats: true
            ),
            events: [
                .budgetWarning: event(minutes: BudgetMath.warningMinutes(budget: settings.budgetMinutes)),
                .budgetLimit: event(minutes: BudgetMath.limitMinutes(budget: settings.budgetMinutes)),
            ]
        )
    }

    static var monitoredActivityCount: Int { center.activities.count }
}
