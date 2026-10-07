import SwiftUI

enum Theme {
    static let indigo = Color(red: 0.31, green: 0.32, blue: 0.91)
    static let bgTop = Color(red: 0.13, green: 0.12, blue: 0.36)
    static let bgBottom = Color(red: 0.05, green: 0.05, blue: 0.15)
    static let card = Color.white.opacity(0.08)
    static let cardBorder = Color.white.opacity(0.10)
    static let subtle = Color(red: 0.72, green: 0.72, blue: 0.92)

    static let keep = Color(red: 0.14, green: 0.64, blue: 0.43)
    static let delete = Color(red: 0.94, green: 0.35, blue: 0.30)
    static let favorite = Color(red: 0.20, green: 0.50, blue: 0.95)
    static let flame = Color(red: 1.00, green: 0.70, blue: 0.20)

    static var background: some View {
        RadialGradient(
            colors: [Color(red: 0.24, green: 0.24, blue: 0.62), bgTop, bgBottom],
            center: .top, startRadius: 40, endRadius: 900
        )
        .ignoresSafeArea()
    }
}

struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Theme.cardBorder))
    }
}

extension View {
    func cardStyle() -> some View { modifier(CardBackground()) }
}

enum Format {
    /// Compact sizes like "3.4MB" / "2.4GB", matching the app's visual style.
    static func bytes(_ value: Int64) -> String {
        let b = Double(value)
        if b >= 1_000_000_000 { return String(format: "%.1fGB", b / 1_000_000_000) }
        if b >= 1_000_000 { return String(format: "%.1fMB", b / 1_000_000) }
        if b >= 1_000 { return String(format: "%.0fKB", b / 1_000) }
        return "\(value)B"
    }

    static func number(_ value: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "en_US")
        return f.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "he_IL")
        f.dateFormat = "d בMMMM yyyy"
        return f
    }()

    static func date(_ date: Date?) -> String {
        guard let date else { return "" }
        return dateFormatter.string(from: date)
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let s = Int(seconds.rounded())
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

enum Haptics {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
