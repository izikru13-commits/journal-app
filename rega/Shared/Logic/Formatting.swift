import Foundation

enum DurationText {
    /// "2 ש׳ 15 ד׳", "45 ד׳", "פחות מדקה".
    static func short(_ interval: TimeInterval) -> String {
        let totalMinutes = Int((interval / 60).rounded(.down))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 && minutes > 0 { return "\(hours) ש׳ \(minutes) ד׳" }
        if hours > 0 { return "\(hours) ש׳" }
        if minutes > 0 { return "\(minutes) ד׳" }
        return "פחות מדקה"
    }

    /// "23:00", for minutes after midnight.
    static func clock(_ minuteOfDay: Int) -> String {
        let m = ((minuteOfDay % 1440) + 1440) % 1440
        return String(format: "%02d:%02d", m / 60, m % 60)
    }

    static func clock(_ date: Date, calendar: Calendar = .rega) -> String {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }

    static func percent(_ value: Double?) -> String {
        guard let value else { return "–" }
        return "\(Int((value * 100).rounded()))%"
    }

    /// Short Hebrew weekday letters, Sunday first.
    static let weekdayLetters = ["א׳", "ב׳", "ג׳", "ד׳", "ה׳", "ו׳", "ש׳"]

    static func weekdays(_ days: Set<Int>) -> String {
        if days.count == 7 { return "כל יום" }
        if days == Set(1...5) { return "א׳–ה׳" }
        if days == [6, 7] { return "סוף שבוע" }
        return (1...7).filter(days.contains).map { weekdayLetters[$0 - 1] }.joined(separator: " ")
    }
}
