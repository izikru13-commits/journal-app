import SwiftUI

@main
struct SwipeCleanApp: App {
    @StateObject private var store = ProgressStore(startFresh: AppEnvironment.isUITesting)
    @StateObject private var library = PhotoLibraryService()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(library)
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.locale, Locale(identifier: "he_IL"))
                .preferredColorScheme(.dark)
                .tint(Theme.indigo)
        }
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .active:
                library.refreshAuthorization()
                store.rollDayIfNeeded()
            case .background:
                NotificationManager.reschedule(enabled: store.data.reminderEnabled && store.data.onboarded,
                                               hour: store.data.reminderHour,
                                               minute: store.data.reminderMinute,
                                               goal: store.data.dailyGoal,
                                               remaining: library.remaining[.all] ?? store.data.dailyGoal,
                                               todayDone: store.todayDone)
            default:
                break
            }
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var store: ProgressStore
    @EnvironmentObject private var library: PhotoLibraryService

    var body: some View {
        Group {
            if !store.data.onboarded || library.authStatus == .notDetermined {
                OnboardingView()
            } else if !library.hasAccess {
                PermissionDeniedView()
            } else {
                HomeView()
            }
        }
    }
}

enum AppEnvironment {
    /// Set by the UI tests: start with a clean progress file and skip the notification prompt.
    static let isUITesting = ProcessInfo.processInfo.arguments.contains("-uiTesting")
}
