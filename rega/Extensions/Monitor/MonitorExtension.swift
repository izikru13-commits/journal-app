import DeviceActivity
import Foundation
import ManagedSettings

/// Kept deliberately tiny: the system kills this extension above ~6 MB.
/// Every callback only nudges `ShieldEngine.reconcile`, which decides from the clock,
/// so a duplicated or early callback can't create a lock the schedule doesn't justify.
final class MonitorExtension: DeviceActivityMonitor {
    private let store = SharedStore.shared

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        let now = Date()
        switch RegaActivity(activity) {
        case let .lock(id):
            ShieldEngine.reconcile(now: now, hints: [id: .starting], store: store)
        case let .relock(key):
            ShieldEngine.reconcile(now: now, expiringTargetKey: key, store: store)
        case .budget:
            // A new day: thresholds restart, and so does the spurious-event guard.
            var state = store.budget
            state.monitoringStartedAt = now
            store.budget = state
            ShieldEngine.reconcile(now: now, store: store)
        case .manual, .unknown:
            ShieldEngine.reconcile(now: now, store: store)
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        let now = Date()
        switch RegaActivity(activity) {
        case let .lock(id):
            ShieldEngine.reconcile(now: now, hints: [id: .ending], store: store)
        case .relock:
            DeviceActivityCenter().stopMonitoring([activity])
            ShieldEngine.reconcile(now: now, store: store)
        case .manual:
            if let manual = store.manualSession, manual.end <= now.addingTimeInterval(LockSchedule.startTolerance) {
                store.manualSession = nil
            }
            ShieldEngine.reconcile(now: now, store: store)
        case .budget, .unknown:
            ShieldEngine.reconcile(now: now, store: store)
        }
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        guard RegaActivity(activity) == .budget else { return }
        let now = Date()
        var state = store.budget
        // Reported to fire right after startMonitoring on some iOS versions: ignore those.
        guard !BudgetMath.isLikelySpurious(eventAt: now, monitoringStartedAt: state.monitoringStartedAt) else { return }
        let settings = store.settings
        guard settings.budgetEnabled else { return }
        let today = DayKey.make(now)

        if event == .budgetWarning, state.warnedDay != today {
            state.warnedDay = today
            store.budget = state
            Notifier.postBudgetWarning(minutesLeft: settings.budgetMinutes - BudgetMath.warningMinutes(budget: settings.budgetMinutes))
        } else if event == .budgetLimit, state.exceededDay != today {
            state.exceededDay = today
            store.budget = state
            ShieldEngine.reconcile(now: now, store: store)
            Notifier.postBudgetReached()
        }
    }
}
