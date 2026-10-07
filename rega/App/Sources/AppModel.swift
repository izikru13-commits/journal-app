import Combine
import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings
import SwiftUI
import WidgetKit

enum MainTab: Hashable {
    case home, locks, stats, settings
}

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    let store = SharedStore.shared

    @Published private(set) var authorization: AuthorizationStatus = .notDetermined
    @Published private(set) var notificationsAuthorized = false
    @Published private(set) var settings = RegaSettings()
    @Published private(set) var distractions = FamilyActivitySelection()
    @Published private(set) var locks: [LockRule] = []
    @Published private(set) var protection = ActiveProtection()
    @Published private(set) var counters: [String: DayCounters] = [:]
    @Published private(set) var events: [RegaEvent] = []
    @Published private(set) var replacements: [ReplacementActivity] = []
    @Published private(set) var unlocks: [GateUnlock] = []
    @Published private(set) var keySecret: String?
    @Published private(set) var nfcTagID: String?
    @Published private(set) var emergencyRemaining = EmergencyExits.weeklyLimit
    @Published private(set) var budget = BudgetState()

    @Published var intervention: PendingRequest?
    @Published var showUnlock = false
    @Published var tab: MainTab = .home
    @Published var alert: String?

    private var autoPresented = Set<UUID>()
    private var cancellables = Set<AnyCancellable>()

    init() {
        if DemoMode.isActive {
            DemoData.seed(store, screen: DemoMode.screen ?? "")
        } else {
            authorization = AuthorizationCenter.shared.authorizationStatus
            AuthorizationCenter.shared.$authorizationStatus
                .receive(on: RunLoop.main)
                .sink { [weak self] in self?.authorization = $0 }
                .store(in: &cancellables)
        }
        if store.installDate == nil { store.installDate = Date() }
        load()
    }

    // MARK: - Derived

    var today: DayCounters { counters[DayKey.make(Date())] ?? DayCounters() }
    var canWeaken: Bool { ProtectionGuard.canWeaken(protection) }
    var isAuthorized: Bool { authorization == .approved || DemoMode.isActive }
    var distractionCount: Int { TokenSets(distractions).count }
    var activeUnlocks: [GateUnlock] { UnlockMath.active(unlocks, at: Date()) }

    var streak: Int {
        StatsMath.streak(counters: counters, goal: settings.dailyApprovedGoal, today: Date(), since: store.installDate)
    }

    func pendingFreshRequest(now: Date = Date()) -> PendingRequest? {
        guard let pending = store.pendingRequest, pending.isFresh(at: now) else { return nil }
        return pending
    }

    // MARK: - Loading & reconciling

    private func load(now: Date = Date()) {
        settings = store.settings
        distractions = store.distractions
        locks = store.locks
        counters = store.counters
        events = store.events
        replacements = store.replacements
        unlocks = store.unlocks
        keySecret = store.keySecret
        nfcTagID = store.nfcTagID
        budget = store.budget
        let uses = EmergencyExits.pruned(store.emergencyUses, now: now)
        emergencyRemaining = EmergencyExits.remaining(uses, now: now)
        protection = ShieldEngine.currentProtection(now: now, store: store)
    }

    /// Called on foreground, on a timer while visible, and after every change.
    func refresh(now: Date = Date()) {
        if !DemoMode.isActive {
            protection = ShieldEngine.reconcile(now: now, store: store)
            ActivityScheduler.cleanupRelocks(activeUnlocks: store.unlocks)
        }
        load(now: now)
        if let pending = pendingFreshRequest(now: now), intervention == nil, !autoPresented.contains(pending.id) {
            autoPresented.insert(pending.id)
            intervention = pending
        }
        Task { notificationsAuthorized = await Notifier.isAuthorized() }
    }

    /// First launch after install/update: make sure every schedule exists.
    func ensureSchedules() {
        guard !DemoMode.isActive, isAuthorized else { return }
        let monitored = Set(DeviceActivityCenter().activities.map(\.rawValue))
        let missingLock = locks.contains { $0.isEnabled && !monitored.contains(DeviceActivityName.lock($0.id).rawValue) }
        if missingLock { report(ActivityScheduler.syncLocks(locks)) }
        if settings.budgetEnabled && !monitored.contains(DeviceActivityName.budget.rawValue) {
            syncBudget()
        }
        BackgroundRefresh.schedule()
    }

    private func afterEventLogged() {
        load()
        guard !DemoMode.isActive else { return }
        Notifier.rescheduleSummaries(store: store)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func report(_ errors: [Error]) {
        if let error = errors.first {
            alert = String(localized: "iOS סירבה לתזמן נעילה: \(error.localizedDescription)")
        }
    }

    private func syncBudget() {
        do {
            try ActivityScheduler.syncBudget(settings: store.settings, store: store)
        } catch {
            alert = String(localized: "לא הצלחתי להפעיל את התקציב היומי: \(error.localizedDescription)")
        }
    }

    // MARK: - Permissions

    func requestScreenTime() async {
        guard !DemoMode.isActive else { return }
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        } catch {
            alert = String(localized: "האישור ל-Screen Time לא הושלם. ודא ש-Screen Time מופעל בהגדרות ונסה שוב.")
        }
        authorization = AuthorizationCenter.shared.authorizationStatus
    }

    func requestNotifications() async {
        guard !DemoMode.isActive else { return }
        notificationsAuthorized = await Notifier.requestAuthorization()
        if notificationsAuthorized { Notifier.rescheduleSummaries(store: store) }
    }

    func handleNotification(route: String?, requestID: String?) {
        switch route.flatMap(NotificationRoute.init(rawValue:)) {
        case .intervention:
            if let pending = store.pendingRequest, pending.id.uuidString == requestID || requestID == nil {
                autoPresented.insert(pending.id)
                intervention = pending
            }
        case .unlock:
            tab = .locks
            showUnlock = true
        case .stats:
            tab = .stats
        case .home, nil:
            tab = .home
        }
        refresh()
    }

    // MARK: - Distractions

    /// Returns false (and explains) when the change would weaken a strict lock.
    @discardableResult
    func updateDistractions(_ selection: FamilyActivitySelection) -> Bool {
        if !canWeaken && !TokenSets(selection).isSuperset(of: TokenSets(distractions)) {
            alert = String(localized: "בזמן נעילה קשיחה אפשר רק להוסיף אפליקציות, לא להסיר.")
            return false
        }
        store.distractions = selection
        if settings.budgetEnabled { syncBudget() }
        refresh()
        return true
    }

    // MARK: - Settings

    func updateSettings(_ change: (inout RegaSettings) -> Void) {
        let old = store.settings
        var new = old
        change(&new)
        if !canWeaken && Self.weakens(old: old, new: new) {
            alert = String(localized: "השינוי הזה מחליש את ההגנה, אז הוא יחכה לסוף הנעילה הקשיחה.")
            load()
            return
        }
        store.settings = new
        if old.budgetEnabled != new.budgetEnabled || old.budgetMinutes != new.budgetMinutes {
            if !DemoMode.isActive { syncBudget() }
        }
        if old.eveningSummaryEnabled != new.eveningSummaryEnabled
            || old.eveningSummaryMinute != new.eveningSummaryMinute
            || old.weeklySummaryEnabled != new.weeklySummaryEnabled {
            if !DemoMode.isActive { Notifier.rescheduleSummaries(store: store) }
        }
        refresh()
    }

    static func weakens(old: RegaSettings, new: RegaSettings) -> Bool {
        (old.gateEnabled && !new.gateEnabled)
            || new.delayBaseSeconds < old.delayBaseSeconds
            || new.delayStepSeconds < old.delayStepSeconds
            || new.delayMaxSeconds < old.delayMaxSeconds
            || (old.budgetEnabled && !new.budgetEnabled)
            || (new.budgetEnabled && new.budgetMinutes > old.budgetMinutes)
            || (old.denyAppRemovalDuringStrict && !new.denyAppRemovalDuringStrict)
            || (old.nfcEnabled && !new.nfcEnabled)
    }

    // MARK: - Gate intervention

    func approvedTodayCount() -> Int { today.approved }

    func delaySeconds() -> Int {
        DelayPolicy.seconds(approvedToday: today.approved, settings: settings)
    }

    func presentation(for target: ShieldTarget) -> ShieldPresentation {
        ShieldLogic.presentation(
            application: TokenCoding.applicationToken(target),
            category: TokenCoding.categoryToken(target),
            webDomain: TokenCoding.webDomainToken(target),
            store: store
        )
    }

    /// "I gave up" from inside the app (after the breathing, or by choosing a replacement).
    func dismiss(_ request: PendingRequest, source: String, intention: Intention? = nil) {
        EventLog.record(
            RegaEvent(date: Date(), kind: .dismissed, targetKey: request.target.key, intention: intention, source: source),
            store: store
        )
        if store.pendingRequest?.id == request.id { store.pendingRequest = nil }
        afterEventLogged()
    }

    /// Opens the gate for one target for a few minutes and schedules the shield's return.
    func approve(_ request: PendingRequest, intention: Intention?, minutes: Int, now: Date = Date()) -> GateUnlock {
        let unlock = UnlockMath.make(target: request.target, minutes: minutes, now: now)
        store.unlocks = UnlockMath.merge(UnlockMath.active(store.unlocks, at: now), with: unlock)
        if store.pendingRequest?.id == request.id { store.pendingRequest = nil }
        EventLog.record(
            RegaEvent(date: now, kind: .approved, targetKey: request.target.key, intention: intention, minutes: minutes, source: "intervention"),
            store: store
        )
        if !DemoMode.isActive {
            ShieldEngine.reconcile(now: now, store: store)
            do {
                try ActivityScheduler.scheduleRelock(for: unlock)
            } catch {
                alert = String(localized: "iOS לא קיבלה את הטיימר. המגן יחזור בפעם הבאה שרגע או הרחבה שלו ירוצו.")
            }
        }
        afterEventLogged()
        return unlock
    }

    /// Ends an opening early (always allowed: it only strengthens protection).
    func relockNow(_ unlock: GateUnlock) {
        store.unlocks = store.unlocks.filter { $0.target.key != unlock.target.key }
        refresh()
    }

    func openNowURL(for target: ShieldTarget) -> URL? {
        KnownApps.urlScheme(forBundleID: store.bundleIDs[target.key]).flatMap(URL.init(string:))
    }

    func replacement(for request: PendingRequest) -> ReplacementActivity? {
        guard !replacements.isEmpty else { return nil }
        let index = (today.attempts + Int(request.createdAt.timeIntervalSince1970) / 60) % replacements.count
        return replacements[index]
    }

    // MARK: - Locks

    func saveLock(_ rule: LockRule, selection: FamilyActivitySelection?) {
        var rule = rule
        rule.durationMinutes = min(max(rule.durationMinutes, LockRule.minimumDuration), LockRule.maximumDuration)
        let isExisting = locks.contains { $0.id == rule.id }
        if isExisting && !canWeaken {
            alert = String(localized: "אי אפשר לערוך נעילות קיימות בזמן נעילה קשיחה. אפשר להוסיף חדשות.")
            return
        }
        var all = store.locks
        if let index = all.firstIndex(where: { $0.id == rule.id }) {
            all[index] = rule
        } else {
            all.append(rule)
        }
        store.locks = all
        store.setSelection(rule.usesDistractions ? nil : selection, forLock: rule.id)
        if !DemoMode.isActive { report(ActivityScheduler.syncLocks(all)) }
        refresh()
    }

    func setLock(_ id: UUID, enabled: Bool) {
        guard var rule = locks.first(where: { $0.id == id }) else { return }
        if !enabled && !canWeaken {
            alert = String(localized: "אי אפשר לכבות נעילה בזמן נעילה קשיחה.")
            return
        }
        rule.isEnabled = enabled
        var all = store.locks
        if let index = all.firstIndex(where: { $0.id == id }) { all[index] = rule }
        store.locks = all
        if !DemoMode.isActive { report(ActivityScheduler.syncLocks(all)) }
        refresh()
    }

    func deleteLock(_ id: UUID) {
        guard canWeaken else {
            alert = String(localized: "אי אפשר למחוק נעילה בזמן נעילה קשיחה.")
            return
        }
        let all = store.locks.filter { $0.id != id }
        store.locks = all
        store.setSelection(nil, forLock: id)
        if !DemoMode.isActive { report(ActivityScheduler.syncLocks(all)) }
        refresh()
    }

    func startManualLock(minutes: Int, strict: Bool, now: Date = Date()) {
        let end = now.addingTimeInterval(TimeInterval(minutes * 60))
        if let current = store.manualSession, current.end > now, !canWeaken || current.isStrict {
            // Never shorten or soften an active strict session; only extend it.
            store.manualSession = ManualSession(id: current.id, start: current.start, end: max(end, current.end), isStrict: current.isStrict || strict)
        } else {
            store.manualSession = ManualSession(id: UUID(), start: now, end: end, isStrict: strict)
        }
        if !DemoMode.isActive, let session = store.manualSession {
            do {
                try ActivityScheduler.startManual(session, now: now)
            } catch {
                alert = String(localized: "הנעילה פעילה, אבל iOS לא קיבלה את הטיימר לסיום. היא תסתיים בפתיחה הבאה של רגע.")
            }
        }
        EventLog.record(RegaEvent(date: now, kind: .lockStarted, minutes: minutes, source: "manual"), store: store)
        afterEventLogged()
        refresh()
    }

    /// Ends every active lock until its current occurrence is over.
    private func endActiveLocks(kind: EventKind, source: String, now: Date = Date()) {
        let current = ShieldEngine.currentProtection(now: now, store: store)
        store.lockOverrides = store.lockOverrides.filter { $0.until > now } + ProtectionEvaluator.overridesEnding(current)
        if current.manual != nil {
            store.manualSession = nil
            if !DemoMode.isActive { ActivityScheduler.stopManual() }
        }
        EventLog.record(RegaEvent(date: now, kind: kind, source: source), store: store)
        afterEventLogged()
        refresh()
    }

    /// Soft locks end with a tap; strict ones need the key.
    func endSoftLocks() {
        guard !protection.isStrict else { return }
        endActiveLocks(kind: .lockEndedSoft, source: "soft")
    }

    func endBudgetForToday() {
        var state = store.budget
        state.dismissedDay = DayKey.make(Date())
        store.budget = state
        refresh()
    }

    @discardableResult
    func endLocks(withScannedCode code: String) -> Bool {
        guard KeyCodec.matches(scanned: code, secret: store.keySecret) else { return false }
        endActiveLocks(kind: .lockEndedWithKey, source: "qr")
        return true
    }

    @discardableResult
    func endLocks(withNFCTag tagID: String) -> Bool {
        guard settings.nfcEnabled, let paired = store.nfcTagID, paired == tagID else { return false }
        endActiveLocks(kind: .lockEndedWithKey, source: "nfc")
        return true
    }

    @discardableResult
    func useEmergencyExit(phrase: String, now: Date = Date()) -> Bool {
        let uses = EmergencyExits.pruned(store.emergencyUses, now: now)
        guard EmergencyExits.matches(phrase), EmergencyExits.remaining(uses, now: now) > 0 else { return false }
        store.emergencyUses = uses + [now]
        endActiveLocks(kind: .emergencyExit, source: "emergency", now: now)
        return true
    }

    // MARK: - Key

    func generateKey() {
        if keySecret != nil && !canWeaken {
            alert = String(localized: "אי אפשר להחליף מפתח בזמן נעילה קשיחה.")
            return
        }
        store.keySecret = KeyCodec.newSecret()
        load()
    }

    func pairNFC(tagID: String) {
        if nfcTagID != nil && !canWeaken {
            alert = String(localized: "אי אפשר להחליף תג בזמן נעילה קשיחה.")
            return
        }
        store.nfcTagID = tagID
        load()
    }

    func unpairNFC() {
        guard canWeaken else {
            alert = String(localized: "אי אפשר להסיר את התג בזמן נעילה קשיחה.")
            return
        }
        store.nfcTagID = nil
        load()
    }

    // MARK: - Replacements

    func saveReplacements(_ list: [ReplacementActivity]) {
        store.replacements = list
        load()
    }

    // MARK: - Onboarding

    func completeOnboarding(sleepStart: Int, sleepEnd: Int, wakeMinute: Int, sleepStrict: Bool, morningStrict: Bool) {
        var sleep = LockRule.sleep(startMinute: sleepStart, endMinute: sleepEnd)
        sleep.isStrict = sleepStrict
        var morning = LockRule.morning(wakeMinute: wakeMinute)
        morning.isStrict = morningStrict
        let custom = store.locks.filter { $0.kind == .custom }
        store.locks = [sleep, morning] + custom
        var settings = store.settings
        settings.wakeMinute = wakeMinute
        settings.onboardingCompleted = true
        store.settings = settings
        if !DemoMode.isActive {
            report(ActivityScheduler.syncLocks(store.locks))
            Notifier.rescheduleSummaries(store: store)
            BackgroundRefresh.schedule()
        }
        refresh()
    }

    func resyncSchedules() {
        guard !DemoMode.isActive else { return }
        report(ActivityScheduler.syncLocks(store.locks))
        if settings.budgetEnabled { syncBudget() }
        refresh()
    }
}
