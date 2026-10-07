import Foundation

enum EventLog {
    static let retentionDays = 60

    /// Appends an event and updates the compact per-day counters.
    static func record(_ event: RegaEvent, store: SharedStore = .shared, calendar: Calendar = .rega) {
        var events = store.events
        events.append(event)
        let cutoff = event.date.addingTimeInterval(-Double(retentionDays) * 86_400)
        events.removeAll { $0.date < cutoff }
        store.events = events

        var counters = store.counters
        let key = DayKey.make(event.date, calendar: calendar)
        var day = counters[key] ?? DayCounters()
        day.apply(event)
        counters[key] = day
        let oldestKept = DayKey.make(event.date.addingTimeInterval(-400 * 86_400), calendar: calendar)
        counters = counters.filter { $0.key >= oldestKept }
        store.counters = counters
    }

    /// Records an attempt unless one for the same target was recorded within `window`.
    @discardableResult
    static func recordAttempt(
        targetKey: String, at date: Date, window: TimeInterval, source: String, store: SharedStore = .shared
    ) -> Bool {
        var last = store.lastAttempts
        guard AttemptDeduper.shouldRecord(key: targetKey, at: date, last: last, window: window) else { return false }
        last[targetKey] = date
        last = last.filter { date.timeIntervalSince($0.value) < 86_400 }
        store.lastAttempts = last
        record(RegaEvent(date: date, kind: .attempt, targetKey: targetKey, source: source), store: store)
        return true
    }
}
