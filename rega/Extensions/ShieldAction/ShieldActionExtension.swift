import Foundation
import ManagedSettings
import WidgetKit

/// Shield buttons. A shield cannot open the app through any public API, so "open anyway"
/// stores a pending request and posts a notification; tapping it is welcome extra friction.
final class ShieldActionExtension: ShieldActionDelegate {
    private let store = SharedStore.shared

    override func handle(
        action: ShieldAction, for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        handle(
            action: action, application: application, category: nil, webDomain: nil,
            target: TokenCoding.target(application: application), completion: completionHandler
        )
    }

    override func handle(
        action: ShieldAction, for webDomain: WebDomainToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        handle(
            action: action, application: nil, category: nil, webDomain: webDomain,
            target: TokenCoding.target(webDomain: webDomain), completion: completionHandler
        )
    }

    override func handle(
        action: ShieldAction, for category: ActivityCategoryToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        handle(
            action: action, application: nil, category: category, webDomain: nil,
            target: TokenCoding.target(category: category), completion: completionHandler
        )
    }

    private func handle(
        action: ShieldAction,
        application: ApplicationToken?,
        category: ActivityCategoryToken?,
        webDomain: WebDomainToken?,
        target: ShieldTarget?,
        completion: @escaping (ShieldActionResponse) -> Void
    ) {
        let now = Date()
        // Safety net: re-shield anything whose opening expired.
        ShieldEngine.reconcile(now: now, store: store)

        let presentation = ShieldLogic.presentation(
            application: application, category: category, webDomain: webDomain, now: now, store: store
        )

        switch (presentation, action) {
        case (.gate, .primaryButtonPressed):
            if let target {
                EventLog.recordAttempt(targetKey: target.key, at: now, window: AttemptDeduper.actionWindow, source: "action", store: store)
            }
            EventLog.record(RegaEvent(date: now, kind: .dismissed, targetKey: target?.key, source: "shield"), store: store)
            finish(.close, completion: completion)

        case (.gate, .secondaryButtonPressed):
            guard let target else {
                completion(.close)
                return
            }
            EventLog.recordAttempt(targetKey: target.key, at: now, window: AttemptDeduper.actionWindow, source: "action", store: store)
            let request = PendingRequest(id: UUID(), target: target, createdAt: now)
            store.pendingRequest = request
            Notifier.postContinue(request) { [weak self] in
                self?.finish(.close, completion: completion)
            }

        case (.lock(_, _, false), .secondaryButtonPressed), (.budget, .secondaryButtonPressed):
            Notifier.postLockEndRequest {
                completion(.close)
            }

        default:
            completion(.close)
        }
    }

    private func finish(_ response: ShieldActionResponse, completion: @escaping (ShieldActionResponse) -> Void) {
        Notifier.rescheduleSummaries(store: store)
        WidgetCenter.shared.reloadAllTimelines()
        completion(response)
    }
}
