import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Calm, dark Hebrew shields. Also counts the attempt (shield display) and remembers the
/// app's bundle id for the "open now" button. Writes here are best effort: the
/// ShieldAction extension is the reliable writer and re-counts if this one didn't.
final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    private let store = SharedStore.shared

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        configuration(
            application: application.token, category: nil, webDomain: nil,
            target: application.token.flatMap(TokenCoding.target(application:)),
            bundleID: application.bundleIdentifier
        )
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        configuration(
            application: application.token, category: category.token, webDomain: nil,
            target: application.token.flatMap(TokenCoding.target(application:))
                ?? category.token.flatMap(TokenCoding.target(category:)),
            bundleID: application.bundleIdentifier
        )
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        configuration(
            application: nil, category: nil, webDomain: webDomain.token,
            target: webDomain.token.flatMap(TokenCoding.target(webDomain:)),
            bundleID: nil
        )
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        configuration(
            application: nil, category: category.token, webDomain: webDomain.token,
            target: webDomain.token.flatMap(TokenCoding.target(webDomain:))
                ?? category.token.flatMap(TokenCoding.target(category:)),
            bundleID: nil
        )
    }

    private func configuration(
        application: ApplicationToken?,
        category: ActivityCategoryToken?,
        webDomain: WebDomainToken?,
        target: ShieldTarget?,
        bundleID: String?
    ) -> ShieldConfiguration {
        let now = Date()
        let presentation = ShieldLogic.presentation(
            application: application, category: category, webDomain: webDomain, now: now, store: store
        )
        if let target {
            EventLog.recordAttempt(targetKey: target.key, at: now, window: AttemptDeduper.shieldWindow, source: "shield", store: store)
            if let bundleID, store.bundleIDs[target.key] != bundleID {
                var map = store.bundleIDs
                map[target.key] = bundleID
                store.bundleIDs = map
            }
        }
        let attempts = store.counters(for: now).attempts

        switch presentation {
        case .gate:
            return ShieldStyle.make(
                symbol: "wind",
                title: String(localized: "רגע."),
                subtitle: ShieldTexts.attemptsSubtitle(attempts) + "\n\n" + ShieldTexts.line(attempts: attempts, now: now),
                primary: String(localized: "ויתרתי"),
                secondary: String(localized: "בכל זאת לפתוח")
            )
        case let .lock(name, until, strict):
            let untilText = ShieldTexts.until(until)
            return ShieldStyle.make(
                symbol: strict ? "lock.fill" : "moon.zzz",
                title: String(localized: "\(name) · נעול עד \(untilText)"),
                subtitle: strict
                    ? String(localized: "זו נעילה קשיחה. רק המפתח הפיזי שלך יכול לסיים אותה מוקדם.")
                    : String(localized: "הזמן הזה שמור לך. אפשר לסיים את הנעילה מתוך רגע."),
                primary: String(localized: "סגירה"),
                secondary: strict ? nil : String(localized: "לסיים ברגע")
            )
        case .budget:
            return ShieldStyle.make(
                symbol: "hourglass.bottomhalf.filled",
                title: String(localized: "התקציב של היום נגמר"),
                subtitle: String(localized: "נתראה מחר. בינתיים, אולי משהו מהרשימה של הדברים שעושים במקום?"),
                primary: String(localized: "סגירה"),
                secondary: String(localized: "לסיים ברגע")
            )
        }
    }
}

enum ShieldStyle {
    static let background = UIColor(red: 0.055, green: 0.067, blue: 0.086, alpha: 1)
    static let accent = UIColor(red: 0.506, green: 0.831, blue: 0.706, alpha: 1)
    static let primaryText = UIColor(white: 0.95, alpha: 1)
    static let secondaryText = UIColor(white: 0.68, alpha: 1)

    static func make(symbol: String, title: String, subtitle: String, primary: String, secondary: String?) -> ShieldConfiguration {
        let icon = UIImage(
            systemName: symbol,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 44, weight: .light)
        )?.withTintColor(accent, renderingMode: .alwaysOriginal)

        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: background,
            icon: icon,
            title: ShieldConfiguration.Label(text: title, color: primaryText),
            subtitle: ShieldConfiguration.Label(text: subtitle, color: secondaryText),
            primaryButtonLabel: ShieldConfiguration.Label(text: primary, color: background),
            primaryButtonBackgroundColor: accent,
            secondaryButtonLabel: secondary.map { ShieldConfiguration.Label(text: $0, color: secondaryText) }
        )
    }
}
