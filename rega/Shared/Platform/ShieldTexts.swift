import Foundation

/// Copy shown on shields. Supportive, a little witty, never guilt-tripping.
enum ShieldTexts {
    static let reflectiveLines: [String] = [
        String(localized: "מה באמת חיפשת עכשיו?"),
        String(localized: "הדחף הזה יעבור תוך דקה. אפשר לחכות לו."),
        String(localized: "שום דבר שם לא ייעלם אם תבדוק אחר כך."),
        String(localized: "האצבע הגיעה לפני ההחלטה. עכשיו אתה מחליט."),
        String(localized: "הפיד ימשיך להסתובב גם בלעדיך. באמת."),
        String(localized: "נשימה אחת לפני שממשיכים?"),
        String(localized: "מה הדבר הכי טוב שאפשר לעשות עכשיו בחמש דקות?"),
        String(localized: "גלילה לא מנקה את הראש, היא רק ממלאת אותו."),
        String(localized: "אם תוותר עכשיו, מה תעשה עם הדקה הזאת?"),
        String(localized: "רגע של שקט שווה יותר מעוד סרטון."),
        String(localized: "עייפות? שעמום? שניהם עוברים יותר טוב בלי מסך."),
        String(localized: "אתה כבר יודע מה יש שם. וזה בסדר לא לבדוק."),
    ]

    static func line(attempts: Int, now: Date = Date(), calendar: Calendar = .rega) -> String {
        let day = calendar.ordinality(of: .day, in: .year, for: now) ?? 0
        return reflectiveLines[(day * 5 + attempts) % reflectiveLines.count]
    }

    static func attemptsSubtitle(_ attempts: Int) -> String {
        switch attempts {
        case 0, 1: return String(localized: "זה הניסיון הראשון היום לפתוח אפליקציה מסיחה.")
        default: return String(localized: "זה הניסיון ה-\(attempts) היום לפתוח אפליקציה מסיחה.")
        }
    }

    static func until(_ date: Date?) -> String {
        guard let date else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "he_IL")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
