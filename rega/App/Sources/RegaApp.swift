import BackgroundTasks
import DeviceActivity
import SwiftUI
import UserNotifications

@main
struct RegaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .onOpenURL { url in
                    model.handleNotification(route: url.host, requestID: nil)
                }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                model.refresh()
                model.ensureSchedules()
            } else if phase == .background {
                BackgroundRefresh.schedule()
            }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        if !DemoMode.isActive { BackgroundRefresh.register() }
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let info = response.notification.request.content.userInfo
        let route = info[Notifier.routeKey] as? String
        let requestID = info[Notifier.requestKey] as? String
        Task { @MainActor in
            AppModel.shared.handleNotification(route: route, requestID: requestID)
            completionHandler()
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

/// Opportunistic safety net: iOS wakes the app now and then, and we re-apply expired unlocks.
enum BackgroundRefresh {
    static let identifier = "com.neriya.rega.reconcile"

    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { task in
            schedule()
            ShieldEngine.reconcile()
            ActivityScheduler.cleanupRelocks(activeUnlocks: SharedStore.shared.unlocks)
            task.setTaskCompleted(success: true)
        }
    }

    static func schedule() {
        guard !DemoMode.isActive else { return }
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 20 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
}
