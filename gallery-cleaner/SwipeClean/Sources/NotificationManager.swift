import UserNotifications

enum NotificationManager {
    private static let daysAhead = 14

    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Schedules the "time to clean" reminder for the coming days, skipping today if the goal is done.
    static func reschedule(enabled: Bool, hour: Int, minute: Int, goal: Int, remaining: Int, todayDone: Bool) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: (0..<daysAhead).map { "daily-\($0)" })
        guard enabled, remaining > 0 else { return }

        let cal = Calendar.current
        let now = Date()
        let count = min(goal, remaining)
        let minutes = max(1, Int((Double(count) * 6.0 / 60.0).rounded()))

        for offset in 0..<daysAhead {
            if offset == 0 && todayDone { continue }
            guard let day = cal.date(byAdding: .day, value: offset, to: now) else { continue }
            var comps = cal.dateComponents([.year, .month, .day], from: day)
            comps.hour = hour
            comps.minute = minute
            guard let fire = cal.date(from: comps), fire > now else { continue }

            let content = UNMutableNotificationContent()
            content.title = "הגיע הזמן לנקות!"
            content.body = "\(count) פריטים מחכים, בערך \(minutes) דק׳"
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            center.add(UNNotificationRequest(identifier: "daily-\(offset)", content: content, trigger: trigger))
        }
    }
}
