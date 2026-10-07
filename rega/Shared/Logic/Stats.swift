import Foundation

struct DayStat: Identifiable, Equatable {
    var day: Date
    var counters: DayCounters
    var id: Date { day }
}

enum StatsMath {
    /// Share of attempts that did not end in an approved opening (walking away counts as giving up).
    /// The denominator is never smaller than the decisions we know about, in case an attempt went unrecorded.
    static func dismissRate(attempts: Int, dismissed: Int, approved: Int) -> Double? {
        let total = max(attempts, dismissed + approved)
        guard total > 0 else { return nil }
        return Double(total - approved) / Double(total)
    }

    static func lastDays(
        _ count: Int, counters: [String: DayCounters], today: Date, calendar: Calendar = .rega
    ) -> [DayStat] {
        let start = calendar.startOfDay(for: today)
        return (0..<max(count, 0)).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: start) else { return nil }
            return DayStat(day: day, counters: counters[DayKey.make(day, calendar: calendar)] ?? DayCounters())
        }
    }

    static func total(_ days: [DayStat]) -> DayCounters {
        days.reduce(into: DayCounters()) { sum, day in
            sum.attempts += day.counters.attempts
            sum.dismissed += day.counters.dismissed
            sum.approved += day.counters.approved
            sum.approvedMinutes += day.counters.approvedMinutes
        }
    }

    /// Consecutive days, ending today, on which approved openings stayed within the goal.
    /// Days before `since` (install day) don't count.
    static func streak(
        counters: [String: DayCounters], goal: Int, today: Date, since: Date?, calendar: Calendar = .rega
    ) -> Int {
        let first = calendar.startOfDay(for: since ?? today)
        var day = calendar.startOfDay(for: today)
        var streak = 0
        while day >= first {
            let approved = counters[DayKey.make(day, calendar: calendar)]?.approved ?? 0
            guard approved <= goal else { break }
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }

    static func topIntention(_ events: [RegaEvent], since: Date) -> Intention? {
        var counts: [Intention: Int] = [:]
        for event in events where event.date >= since && event.kind == .approved {
            if let intention = event.intention { counts[intention, default: 0] += 1 }
        }
        return counts.max { lhs, rhs in
            lhs.value == rhs.value ? lhs.key.rawValue > rhs.key.rawValue : lhs.value < rhs.value
        }?.key
    }
}
