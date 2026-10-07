import Foundation

enum StoreKey {
    static let distractions = "selection.distractions"
    static func lockSelection(_ id: UUID) -> String { "selection.lock.\(id.uuidString)" }
    static let settings = "settings"
    static let locks = "locks"
    static let manualSession = "manualSession"
    static let lockOverrides = "lockOverrides"
    static let unlocks = "unlocks"
    static let pendingRequest = "pendingRequest"
    static let events = "events"
    static let counters = "counters"
    static let lastAttempts = "lastAttempts"
    static let bundleIDs = "bundleIDs"
    static let budget = "budget"
    static let emergencyUses = "emergencyUses"
    static let keySecret = "key.secret"
    static let keyNFCTag = "key.nfcTag"
    static let replacements = "replacements"
    static let installDate = "installDate"
}

/// Small Codable values in the App Group's `UserDefaults`, readable from every process.
/// Deliberately no database: the monitor extension has a ~6 MB memory ceiling.
final class SharedStore {
    static let shared = SharedStore()

    let defaults: UserDefaults
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return encoder
    }()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults? = nil) {
        if let defaults {
            self.defaults = defaults
        } else if let demo = DemoMode.suiteName {
            self.defaults = UserDefaults(suiteName: demo) ?? .standard
        } else {
            self.defaults = UserDefaults(suiteName: AppGroupID.identifier) ?? .standard
        }
    }

    func read<T: Decodable>(_ type: T.Type, _ key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode(type, from: data)
    }

    func write<T: Encodable>(_ value: T?, _ key: String) {
        guard let value, let data = try? encoder.encode(value) else {
            defaults.removeObject(forKey: key)
            return
        }
        defaults.set(data, forKey: key)
    }

    var settings: RegaSettings {
        get { read(RegaSettings.self, StoreKey.settings) ?? RegaSettings() }
        set { write(newValue, StoreKey.settings) }
    }

    var locks: [LockRule] {
        get { read([LockRule].self, StoreKey.locks) ?? [] }
        set { write(newValue, StoreKey.locks) }
    }

    var manualSession: ManualSession? {
        get { read(ManualSession.self, StoreKey.manualSession) }
        set { write(newValue, StoreKey.manualSession) }
    }

    var lockOverrides: [LockOverride] {
        get { read([LockOverride].self, StoreKey.lockOverrides) ?? [] }
        set { write(newValue, StoreKey.lockOverrides) }
    }

    var unlocks: [GateUnlock] {
        get { read([GateUnlock].self, StoreKey.unlocks) ?? [] }
        set { write(newValue, StoreKey.unlocks) }
    }

    var pendingRequest: PendingRequest? {
        get { read(PendingRequest.self, StoreKey.pendingRequest) }
        set { write(newValue, StoreKey.pendingRequest) }
    }

    var events: [RegaEvent] {
        get { read([RegaEvent].self, StoreKey.events) ?? [] }
        set { write(newValue, StoreKey.events) }
    }

    var counters: [String: DayCounters] {
        get { read([String: DayCounters].self, StoreKey.counters) ?? [:] }
        set { write(newValue, StoreKey.counters) }
    }

    var lastAttempts: [String: Date] {
        get { read([String: Date].self, StoreKey.lastAttempts) ?? [:] }
        set { write(newValue, StoreKey.lastAttempts) }
    }

    var bundleIDs: [String: String] {
        get { read([String: String].self, StoreKey.bundleIDs) ?? [:] }
        set { write(newValue, StoreKey.bundleIDs) }
    }

    var budget: BudgetState {
        get { read(BudgetState.self, StoreKey.budget) ?? BudgetState() }
        set { write(newValue, StoreKey.budget) }
    }

    var emergencyUses: [Date] {
        get { read([Date].self, StoreKey.emergencyUses) ?? [] }
        set { write(newValue, StoreKey.emergencyUses) }
    }

    var keySecret: String? {
        get { defaults.string(forKey: StoreKey.keySecret) }
        set { defaults.set(newValue, forKey: StoreKey.keySecret) }
    }

    var nfcTagID: String? {
        get { defaults.string(forKey: StoreKey.keyNFCTag) }
        set { defaults.set(newValue, forKey: StoreKey.keyNFCTag) }
    }

    var replacements: [ReplacementActivity] {
        get { read([ReplacementActivity].self, StoreKey.replacements) ?? ReplacementActivity.defaults }
        set { write(newValue, StoreKey.replacements) }
    }

    var installDate: Date? {
        get { defaults.object(forKey: StoreKey.installDate) as? Date }
        set { defaults.set(newValue, forKey: StoreKey.installDate) }
    }

    func counters(for date: Date, calendar: Calendar = .rega) -> DayCounters {
        counters[DayKey.make(date, calendar: calendar)] ?? DayCounters()
    }
}

/// Screenshot / UI-test mode: `-regaDemo <screen>` runs the app on a throwaway store with sample data.
enum DemoMode {
    static var screen: String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-regaDemo"), index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
    }

    static var isActive: Bool { screen != nil }
    static var suiteName: String? { isActive ? "rega.demo" : nil }
}
