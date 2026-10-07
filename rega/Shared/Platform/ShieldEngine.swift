import FamilyControls
import Foundation
import ManagedSettings

extension ManagedSettingsStore.Name {
    /// Distractions behind the friction gate. Opened per app for a few minutes.
    static let gate = Self("gate")
    /// Scheduled locks, "lock now" sessions and the daily budget. Never touched by gate unlocks.
    static let locks = Self("locks")
}

/// Applies shields from stored state. Idempotent, so every process may call it at any time;
/// it is the safety net that re-shields expired unlocks whenever the app or an extension runs.
enum ShieldEngine {
    @discardableResult
    static func reconcile(
        now: Date = Date(),
        hints: [UUID: LockHint] = [:],
        expiringTargetKey: String? = nil,
        store: SharedStore = .shared
    ) -> ActiveProtection {
        // 1. Prune expired gate unlocks.
        let storedUnlocks = store.unlocks
        let unlocks = UnlockMath.active(storedUnlocks, at: now).filter { $0.target.key != expiringTargetKey }
        if unlocks.count != storedUnlocks.count { store.unlocks = unlocks }

        // 2. Prune finished manual sessions and stale overrides.
        if let manual = store.manualSession, manual.end <= now { store.manualSession = nil }
        let overrides = store.lockOverrides
        let liveOverrides = overrides.filter { $0.until > now }
        if liveOverrides.count != overrides.count { store.lockOverrides = liveOverrides }

        let settings = store.settings
        let distractions = TokenSets(store.distractions)

        // 3. Gate store: distractions minus active unlocks.
        let gate = ManagedSettingsStore(named: .gate)
        if settings.gateEnabled && !distractions.isEmpty {
            apply(distractions, except: TokenSets(unlocks: unlocks), to: gate)
        } else {
            gate.clearAllSettings()
        }

        // 4. Locks store: union of everything that is active by the clock.
        let protection = ProtectionEvaluator.evaluate(
            rules: store.locks,
            manual: store.manualSession,
            overrides: liveOverrides,
            budget: store.budget,
            settings: settings,
            now: now,
            hints: hints
        )
        let locks = ManagedSettingsStore(named: .locks)
        var locked = TokenSets()
        for active in protection.locks {
            locked.formUnion(TokenSets(store.selection(for: active.rule)))
        }
        if protection.manual != nil || protection.budgetActive {
            locked.formUnion(distractions)
        }
        if locked.isEmpty {
            locks.clearAllSettings()
        } else {
            apply(locked, except: TokenSets(), to: locks)
            locks.application.denyAppRemoval = (protection.isStrict && settings.denyAppRemovalDuringStrict) ? true : nil
        }
        return protection
    }

    static func currentProtection(now: Date = Date(), store: SharedStore = .shared) -> ActiveProtection {
        ProtectionEvaluator.evaluate(
            rules: store.locks,
            manual: store.manualSession,
            overrides: store.lockOverrides,
            budget: store.budget,
            settings: store.settings,
            now: now
        )
    }

    private static func apply(_ sets: TokenSets, except unlocked: TokenSets, to store: ManagedSettingsStore) {
        let applications = sets.applications.subtracting(unlocked.applications)
        store.shield.applications = applications.isEmpty ? nil : applications

        let categories = sets.categories.subtracting(unlocked.categories)
        if categories.isEmpty {
            store.shield.applicationCategories = nil
            store.shield.webDomainCategories = nil
        } else {
            store.shield.applicationCategories = .specific(categories, except: unlocked.applications)
            store.shield.webDomainCategories = .specific(categories, except: unlocked.webDomains)
        }

        let webDomains = sets.webDomains.subtracting(unlocked.webDomains)
        store.shield.webDomains = webDomains.isEmpty ? nil : webDomains
    }
}

/// What a shield should show for a given token. Shared by the configuration and action
/// extensions (and the app) so the buttons always match what was on screen.
enum ShieldPresentation: Equatable {
    case gate
    case lock(name: String, until: Date?, strict: Bool)
    case budget
}

enum ShieldLogic {
    static func presentation(
        application: ApplicationToken?,
        category: ActivityCategoryToken?,
        webDomain: WebDomainToken?,
        now: Date = Date(),
        store: SharedStore = .shared
    ) -> ShieldPresentation {
        let protection = ShieldEngine.currentProtection(now: now, store: store)
        let distractions = TokenSets(store.distractions)

        for active in protection.locks {
            let sets = TokenSets(store.selection(for: active.rule))
            if sets.contains(application: application, category: category, webDomain: webDomain) {
                return .lock(name: active.rule.name, until: active.until, strict: active.rule.isStrict)
            }
        }
        let inDistractions = distractions.contains(application: application, category: category, webDomain: webDomain)
        if let manual = protection.manual, inDistractions {
            return .lock(name: String(localized: "נעילה עכשיו"), until: manual.end, strict: manual.isStrict)
        }
        if protection.budgetActive && inDistractions {
            return .budget
        }
        // Shielded but not recognizable as a distraction (e.g. an app inside a lock's category):
        // it can only be a lock.
        if !inDistractions, let first = protection.locks.first {
            return .lock(name: first.rule.name, until: first.until, strict: first.rule.isStrict)
        }
        if !inDistractions, let manual = protection.manual {
            return .lock(name: String(localized: "נעילה עכשיו"), until: manual.end, strict: manual.isStrict)
        }
        return .gate
    }
}
