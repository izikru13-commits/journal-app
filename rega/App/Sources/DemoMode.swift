import SwiftUI

/// Sample data for UI tests and simulator screenshots (Screen Time doesn't work in the simulator).
/// Lives in its own `UserDefaults` suite, never in the App Group.
enum DemoData {
    static func seed(_ store: SharedStore, screen: String, now: Date = Date()) {
        guard DemoMode.isActive, let suite = DemoMode.suiteName else { return }
        store.defaults.removePersistentDomain(forName: suite)
        let calendar = Calendar.rega

        var settings = RegaSettings()
        settings.onboardingCompleted = !screen.hasPrefix("onboarding")
        settings.budgetEnabled = true
        settings.nfcEnabled = true
        store.settings = settings
        store.installDate = calendar.date(byAdding: .day, value: -20, to: now)
        store.keySecret = "demo-secret"
        store.nfcTagID = "04a1b2c3d4e5f6"

        var sleep = LockRule.sleep()
        sleep.id = UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID()
        var morning = LockRule.morning(wakeMinute: 7 * 60)
        morning.id = UUID(uuidString: "00000000-0000-0000-0000-000000000002") ?? UUID()
        let study = LockRule(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003") ?? UUID(),
            name: "זמן לימוד", kind: .custom, startMinute: 17 * 60, durationMinutes: 120,
            weekdays: Set(1...5), isStrict: false, isEnabled: true, usesDistractions: true
        )
        store.locks = [sleep, morning, study]

        let pattern: [(Int, Int, Int)] = [
            (14, 6, 5), (12, 6, 4), (13, 5, 4), (11, 5, 3), (12, 4, 3), (10, 3, 3), (9, 4, 2),
            (10, 3, 3), (8, 3, 2), (9, 2, 3), (7, 2, 2), (8, 2, 2), (6, 1, 2), (5, 1, 1),
        ]
        var counters: [String: DayCounters] = [:]
        var events: [RegaEvent] = []
        let intentions: [Intention] = [.message, .boredom, .habit, .lookup, .work, .habit]
        for (offset, entry) in pattern.enumerated() {
            guard let day = calendar.date(byAdding: .day, value: offset - (pattern.count - 1), to: now) else { continue }
            let (attempts, approved, minutesEach) = entry
            counters[DayKey.make(day)] = DayCounters(
                attempts: attempts, dismissed: attempts - approved - 1, approved: approved,
                approvedMinutes: approved * minutesEach
            )
            for index in 0..<approved {
                events.append(RegaEvent(date: day, kind: .approved, intention: intentions[(offset + index) % intentions.count], minutes: minutesEach))
            }
        }
        store.counters = counters
        store.events = events

        if screen == "unlock" || screen == "home-locked" {
            store.manualSession = ManualSession(id: UUID(), start: now, end: now.addingTimeInterval(90 * 60), isStrict: true)
            store.emergencyUses = [now.addingTimeInterval(-3600)]
        }
    }

    static var request: PendingRequest {
        PendingRequest(id: UUID(), target: ShieldTarget(kind: .application, tokenData: Data("demo".utf8)), createdAt: Date())
    }
}

struct DemoScreen: View {
    @EnvironmentObject private var model: AppModel
    let screen: String

    var body: some View {
        switch screen {
        case let s where s.hasPrefix("onboarding"):
            OnboardingView(page: Int(s.dropFirst("onboarding".count)) ?? 0)
        case "home", "home-locked":
            MainTabs()
        case "locks":
            MainTabs().onAppear { model.tab = .locks }
        case "stats":
            MainTabs().onAppear { model.tab = .stats }
        case "settings":
            MainTabs().onAppear { model.tab = .settings }
        case "lock-editor":
            NavigationStack {
                LockEditorView(rule: model.locks.first ?? LockRule.sleep(), isNew: false)
            }
        case "manual-lock":
            ManualLockSheet()
        case "unlock":
            UnlockView()
        case "key":
            NavigationStack { KeySetupView() }
        case "tips":
            NavigationStack { TipsView(showsDone: false) }
        case "replacements":
            NavigationStack { ReplacementsEditor() }
        case let s where s.hasPrefix("intervention-"):
            InterventionView(request: DemoData.request, demoStep: step(String(s.dropFirst("intervention-".count))))
        default:
            MainTabs()
        }
    }

    private func step(_ name: String) -> InterventionView.Step {
        switch name {
        case "intention": return .intention
        case "replacement": return .replacement(ReplacementActivity.defaults[0])
        case "duration": return .duration
        case "done":
            return .done(UnlockMath.make(target: DemoData.request.target, minutes: 5, now: Date()))
        case "gaveup": return .gaveUp
        default: return .breathing
        }
    }
}
