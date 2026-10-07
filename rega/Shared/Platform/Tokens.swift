import FamilyControls
import Foundation
import ManagedSettings

/// Opaque Screen Time tokens are Codable; we persist their JSON encoding.
enum TokenCoding {
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return encoder
    }()

    static func target(application token: ApplicationToken) -> ShieldTarget? {
        (try? encoder.encode(token)).map { ShieldTarget(kind: .application, tokenData: $0) }
    }

    static func target(category token: ActivityCategoryToken) -> ShieldTarget? {
        (try? encoder.encode(token)).map { ShieldTarget(kind: .category, tokenData: $0) }
    }

    static func target(webDomain token: WebDomainToken) -> ShieldTarget? {
        (try? encoder.encode(token)).map { ShieldTarget(kind: .webDomain, tokenData: $0) }
    }

    static func applicationToken(_ target: ShieldTarget) -> ApplicationToken? {
        guard target.kind == .application else { return nil }
        return try? JSONDecoder().decode(ApplicationToken.self, from: target.tokenData)
    }

    static func categoryToken(_ target: ShieldTarget) -> ActivityCategoryToken? {
        guard target.kind == .category else { return nil }
        return try? JSONDecoder().decode(ActivityCategoryToken.self, from: target.tokenData)
    }

    static func webDomainToken(_ target: ShieldTarget) -> WebDomainToken? {
        guard target.kind == .webDomain else { return nil }
        return try? JSONDecoder().decode(WebDomainToken.self, from: target.tokenData)
    }
}

/// The three token sets of a selection, with set algebra.
struct TokenSets {
    var applications = Set<ApplicationToken>()
    var categories = Set<ActivityCategoryToken>()
    var webDomains = Set<WebDomainToken>()

    init() {}

    init(_ selection: FamilyActivitySelection) {
        applications = selection.applicationTokens
        categories = selection.categoryTokens
        webDomains = selection.webDomainTokens
    }

    init(unlocks: [GateUnlock]) {
        for unlock in unlocks {
            if let token = TokenCoding.applicationToken(unlock.target) { applications.insert(token) }
            if let token = TokenCoding.categoryToken(unlock.target) { categories.insert(token) }
            if let token = TokenCoding.webDomainToken(unlock.target) { webDomains.insert(token) }
        }
    }

    var isEmpty: Bool { applications.isEmpty && categories.isEmpty && webDomains.isEmpty }
    var count: Int { applications.count + categories.count + webDomains.count }

    mutating func formUnion(_ other: TokenSets) {
        applications.formUnion(other.applications)
        categories.formUnion(other.categories)
        webDomains.formUnion(other.webDomains)
    }

    func contains(application: ApplicationToken?, category: ActivityCategoryToken?, webDomain: WebDomainToken?) -> Bool {
        if let application, applications.contains(application) { return true }
        if let category, categories.contains(category) { return true }
        if let webDomain, webDomains.contains(webDomain) { return true }
        return false
    }

    /// True when every token of `other` is also in `self` (no protection was removed).
    func isSuperset(of other: TokenSets) -> Bool {
        applications.isSuperset(of: other.applications)
            && categories.isSuperset(of: other.categories)
            && webDomains.isSuperset(of: other.webDomains)
    }
}

extension SharedStore {
    var distractions: FamilyActivitySelection {
        get { read(FamilyActivitySelection.self, StoreKey.distractions) ?? FamilyActivitySelection() }
        set { write(newValue, StoreKey.distractions) }
    }

    func selection(for rule: LockRule) -> FamilyActivitySelection {
        guard !rule.usesDistractions else { return distractions }
        return read(FamilyActivitySelection.self, StoreKey.lockSelection(rule.id)) ?? distractions
    }

    func setSelection(_ selection: FamilyActivitySelection?, forLock id: UUID) {
        write(selection, StoreKey.lockSelection(id))
    }
}
