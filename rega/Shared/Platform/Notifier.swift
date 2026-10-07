import Foundation
import UserNotifications

enum NotificationRoute: String {
    case intervention
    case unlock
    case home
    case stats
}

enum Notifier {
    static let routeKey = "route"
    static let requestKey = "requestID"

    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func isAuthorized() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    }

    static func post(
        id: String,
        title: String,
        body: String,
        route: NotificationRoute,
        userInfo: [String: String] = [:],
        trigger: UNNotificationTrigger? = nil,
        completion: (() -> Void)? = nil
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.threadIdentifier = "rega"
        var info = userInfo
        info[routeKey] = route.rawValue
        content.userInfo = info
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { _ in completion?() }
    }

    /// Posted by the ShieldAction extension; tapping it opens the intervention screen.
    static func postContinue(_ request: PendingRequest, completion: (() -> Void)? = nil) {
        post(
            id: "rega.continue",
            title: String(localized: "רגע."),
            body: String(localized: "הקש כדי להמשיך. נעשה את זה בנשימה אחת."),
            route: .intervention,
            userInfo: [requestKey: request.id.uuidString],
            completion: completion
        )
    }

    static func postLockEndRequest(completion: (() -> Void)? = nil) {
        post(
            id: "rega.unlock",
            title: String(localized: "רוצה לסיים את הנעילה?"),
            body: String(localized: "הקש כדי לפתוח את רגע ולהחליט בשקט."),
            route: .unlock,
            completion: completion
        )
    }

    static func postBudgetWarning(minutesLeft: Int) {
        post(
            id: "rega.budget.warning",
            title: String(localized: "נשארו בערך \(minutesLeft) דקות"),
            body: String(localized: "השתמשת ב-80% מהתקציב היומי של האפליקציות המסיחות."),
            route: .home
        )
    }

    static func postBudgetReached() {
        post(
            id: "rega.budget.limit",
            title: String(localized: "התקציב של היום נגמר"),
            body: String(localized: "האפליקציות המסיחות נעולות עד חצות. מחר מתחילים מחדש."),
            route: .home
        )
    }

    // MARK: - Summaries

    /// Local notifications can't compute content at delivery time, so the evening and weekly
    /// summaries are re-scheduled with fresh numbers whenever an event is logged.
    static func rescheduleSummaries(store: SharedStore = .shared, now: Date = Date(), calendar: Calendar = .rega) {
        let center = UNUserNotificationCenter.current()
        let today = calendar.startOfDay(for: now)
        let days = (0..<15).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
        let ids = days.flatMap { ["rega.evening.\(DayKey.make($0))", "rega.weekly.\(DayKey.make($0))"] }
        center.removePendingNotificationRequests(withIdentifiers: ids)

        let settings = store.settings
        let counters = store.counters

        if settings.eveningSummaryEnabled {
            for day in days.prefix(7) {
                guard let fire = calendar.date(byAdding: .minute, value: settings.eveningSummaryMinute, to: day),
                      fire > now
                else { continue }
                let isToday = calendar.isDate(day, inSameDayAs: now)
                let body = isToday ? eveningBody(counters[DayKey.make(day)] ?? DayCounters()) : String(localized: "איך היה היום? הסיכום שלך מחכה ברגע.")
                schedule(id: "rega.evening.\(DayKey.make(day))", title: String(localized: "סיכום הערב"), body: body, at: fire, calendar: calendar)
            }
        }

        if settings.weeklySummaryEnabled {
            var scheduled = 0
            for day in days where calendar.component(.weekday, from: day) == 1 && scheduled < 2 {
                guard let fire = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: day), fire > now else { continue }
                let body = scheduled == 0
                    ? weeklyBody(store: store, endingAt: day, calendar: calendar)
                    : String(localized: "השבוע נגמר. בוא נראה איך הוא היה.")
                schedule(id: "rega.weekly.\(DayKey.make(day))", title: String(localized: "סיכום שבועי"), body: body, at: fire, calendar: calendar)
                scheduled += 1
            }
        }
    }

    private static func schedule(id: String, title: String, body: String, at date: Date, calendar: Calendar) {
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        post(
            id: id, title: title, body: body, route: .stats,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )
    }

    static func eveningBody(_ day: DayCounters) -> String {
        guard day.attempts > 0 || day.approved > 0 else {
            return String(localized: "היום לא ניסית לפתוח אף אפליקציה מסיחה. יום שקט, כל הכבוד 🌙")
        }
        let rate = Int(((day.dismissRate ?? 0) * 100).rounded())
        return String(localized: "היום: \(day.attempts) ניסיונות, \(day.approved) פתיחות (\(day.approvedMinutes) דק׳). ויתרת ב-\(rate)% מהפעמים.")
    }

    private static func weeklyBody(store: SharedStore, endingAt day: Date, calendar: Calendar) -> String {
        let week = StatsMath.lastDays(7, counters: store.counters, today: day, calendar: calendar)
        let total = StatsMath.total(week)
        let rate = Int(((total.dismissRate ?? 0) * 100).rounded())
        let streak = StatsMath.streak(
            counters: store.counters, goal: store.settings.dailyApprovedGoal,
            today: day, since: store.installDate, calendar: calendar
        )
        return String(localized: "השבוע: \(total.attempts) ניסיונות, ויתרת ב-\(rate)% מהם, \(total.approvedMinutes) דקות מאושרות. רצף: \(streak) ימים.")
    }
}
