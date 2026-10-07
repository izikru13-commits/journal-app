import Foundation

/// App Group shared by the app and every extension.
enum AppGroupID {
    static let identifier = "group.com.neriya.rega"
}

// MARK: - Calendar & day keys

extension Calendar {
    /// Gregorian calendar whose week starts on Sunday, as in Israel.
    static var rega: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 1
        calendar.locale = Locale(identifier: "he_IL")
        calendar.timeZone = .current
        return calendar
    }
}

enum DayKey {
    static func make(_ date: Date, calendar: Calendar = .rega) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func date(from key: String, calendar: Calendar = .rega) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
}

/// Deterministic FNV-1a hash, used to derive short keys from opaque token data.
enum StableHash {
    static func hex(_ data: Data) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in data {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return String(format: "%016llx", hash)
    }
}

// MARK: - Shield targets

enum TargetKind: String, Codable {
    case application
    case category
    case webDomain
}

/// An opaque Screen Time token (app, category or web domain) stored as its JSON encoding.
struct ShieldTarget: Codable, Hashable {
    var kind: TargetKind
    var tokenData: Data

    /// Short stable identifier, safe for dictionary keys and activity names.
    var key: String {
        let prefix: String
        switch kind {
        case .application: prefix = "a"
        case .category: prefix = "c"
        case .webDomain: prefix = "w"
        }
        return prefix + StableHash.hex(tokenData)
    }
}

/// A temporary gate opening approved in the intervention flow.
struct GateUnlock: Codable, Hashable {
    var target: ShieldTarget
    var until: Date
    var minutes: Int
}

/// Written by the ShieldAction extension when "open anyway" is tapped.
struct PendingRequest: Codable, Identifiable, Equatable {
    var id: UUID
    var target: ShieldTarget
    var createdAt: Date

    /// Requests older than this are treated as stale.
    static let lifetime: TimeInterval = 15 * 60

    func isFresh(at now: Date) -> Bool {
        now.timeIntervalSince(createdAt) < Self.lifetime && now >= createdAt.addingTimeInterval(-60)
    }
}

// MARK: - Events

enum Intention: String, Codable, CaseIterable, Identifiable {
    case message
    case lookup
    case work
    case boredom
    case habit

    var id: String { rawValue }

    /// Boredom and habit get a replacement activity before any opening.
    var suggestsReplacement: Bool { self == .boredom || self == .habit }
}

enum EventKind: String, Codable {
    case attempt
    case dismissed
    case approved
    case lockStarted
    case lockEndedWithKey
    case lockEndedSoft
    case emergencyExit
    case budgetWarning
    case budgetReached
}

struct RegaEvent: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var date: Date
    var kind: EventKind
    var targetKey: String?
    var intention: Intention?
    var minutes: Int?
    /// Where the event came from, e.g. "shield", "replacement", "intervention".
    var source: String?
}

struct DayCounters: Codable, Equatable {
    var attempts = 0
    var dismissed = 0
    var approved = 0
    var approvedMinutes = 0

    mutating func apply(_ event: RegaEvent) {
        switch event.kind {
        case .attempt:
            attempts += 1
        case .dismissed:
            dismissed += 1
        case .approved:
            approved += 1
            approvedMinutes += event.minutes ?? 0
        default:
            break
        }
    }

    /// Share of attempts that did not end in an approved opening.
    var dismissRate: Double? { StatsMath.dismissRate(attempts: attempts, dismissed: dismissed, approved: approved) }
}

// MARK: - Settings

struct RegaSettings: Codable, Equatable {
    var gateEnabled = true
    var delayBaseSeconds = 8
    var delayStepSeconds = 4
    var delayMaxSeconds = 60
    /// Max approved openings per day that still count toward the streak.
    var dailyApprovedGoal = 5
    var budgetEnabled = false
    var budgetMinutes = 30
    var nfcEnabled = false
    var eveningSummaryEnabled = true
    /// Minutes after midnight.
    var eveningSummaryMinute = 21 * 60 + 30
    var weeklySummaryEnabled = true
    var denyAppRemovalDuringStrict = true
    var wakeMinute = 7 * 60
    var onboardingCompleted = false

    init() {}

    init(from decoder: Decoder) throws {
        // Every field falls back to its default so new settings never break stored data.
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = RegaSettings()
        gateEnabled = try c.decodeIfPresent(Bool.self, forKey: .gateEnabled) ?? d.gateEnabled
        delayBaseSeconds = try c.decodeIfPresent(Int.self, forKey: .delayBaseSeconds) ?? d.delayBaseSeconds
        delayStepSeconds = try c.decodeIfPresent(Int.self, forKey: .delayStepSeconds) ?? d.delayStepSeconds
        delayMaxSeconds = try c.decodeIfPresent(Int.self, forKey: .delayMaxSeconds) ?? d.delayMaxSeconds
        dailyApprovedGoal = try c.decodeIfPresent(Int.self, forKey: .dailyApprovedGoal) ?? d.dailyApprovedGoal
        budgetEnabled = try c.decodeIfPresent(Bool.self, forKey: .budgetEnabled) ?? d.budgetEnabled
        budgetMinutes = try c.decodeIfPresent(Int.self, forKey: .budgetMinutes) ?? d.budgetMinutes
        nfcEnabled = try c.decodeIfPresent(Bool.self, forKey: .nfcEnabled) ?? d.nfcEnabled
        eveningSummaryEnabled = try c.decodeIfPresent(Bool.self, forKey: .eveningSummaryEnabled) ?? d.eveningSummaryEnabled
        eveningSummaryMinute = try c.decodeIfPresent(Int.self, forKey: .eveningSummaryMinute) ?? d.eveningSummaryMinute
        weeklySummaryEnabled = try c.decodeIfPresent(Bool.self, forKey: .weeklySummaryEnabled) ?? d.weeklySummaryEnabled
        denyAppRemovalDuringStrict = try c.decodeIfPresent(Bool.self, forKey: .denyAppRemovalDuringStrict) ?? d.denyAppRemovalDuringStrict
        wakeMinute = try c.decodeIfPresent(Int.self, forKey: .wakeMinute) ?? d.wakeMinute
        onboardingCompleted = try c.decodeIfPresent(Bool.self, forKey: .onboardingCompleted) ?? d.onboardingCompleted
    }
}

// MARK: - Locks

enum LockKind: String, Codable {
    case sleep
    case morning
    case custom
}

struct LockRule: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var kind: LockKind
    /// Minutes after midnight.
    var startMinute: Int
    var durationMinutes: Int
    /// Calendar weekdays, 1 = Sunday … 7 = Saturday. A lock that crosses midnight belongs to its start day.
    var weekdays: Set<Int>
    var isStrict: Bool
    var isEnabled: Bool
    /// When false, the lock uses its own selection stored under `StoreKey.lockSelection(id)`.
    var usesDistractions: Bool

    static let minimumDuration = 15
    static let maximumDuration = 23 * 60 + 45

    var endMinute: Int { (startMinute + durationMinutes) % (24 * 60) }

    static func sleep(startMinute: Int = 23 * 60, endMinute: Int = 7 * 60) -> LockRule {
        LockRule(
            id: UUID(), name: "שינה", kind: .sleep,
            startMinute: startMinute,
            durationMinutes: duration(from: startMinute, to: endMinute),
            weekdays: Set(1...7), isStrict: true, isEnabled: true, usesDistractions: true
        )
    }

    static func morning(wakeMinute: Int) -> LockRule {
        LockRule(
            id: UUID(), name: "בוקר נקי", kind: .morning,
            startMinute: wakeMinute, durationMinutes: 30,
            weekdays: Set(1...7), isStrict: true, isEnabled: true, usesDistractions: true
        )
    }

    /// Duration between two clock times, crossing midnight when needed, clamped to the valid range.
    static func duration(from start: Int, to end: Int) -> Int {
        var minutes = (end - start) % (24 * 60)
        if minutes <= 0 { minutes += 24 * 60 }
        return min(max(minutes, minimumDuration), maximumDuration)
    }
}

struct ManualSession: Codable, Equatable {
    var id: UUID
    var start: Date
    var end: Date
    var isStrict: Bool

    static let allowedMinutes = [15, 30, 45, 60, 90, 120, 180, 240]
}

/// A lock occurrence that was ended early stays off until `until` (the end of that occurrence).
struct LockOverride: Codable, Equatable {
    var lockID: UUID
    var until: Date
}

struct BudgetState: Codable, Equatable {
    var monitoringStartedAt: Date?
    var warnedDay: String?
    var exceededDay: String?
    /// The user ended today's budget lock from the app.
    var dismissedDay: String?
}

struct ReplacementActivity: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var title: String
    var symbol: String

    static let defaults: [ReplacementActivity] = [
        ReplacementActivity(title: "10 שכיבות סמיכה", symbol: "figure.strengthtraining.traditional"),
        ReplacementActivity(title: "לקרוא 5 עמודים", symbol: "book"),
        ReplacementActivity(title: "לשתות מים ולצאת החוצה לדקה", symbol: "drop"),
        ReplacementActivity(title: "להתקשר למישהו שאכפת לך ממנו", symbol: "phone"),
        ReplacementActivity(title: "10 דקות של למידה", symbol: "graduationcap"),
    ]
}
