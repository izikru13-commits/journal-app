import FamilyControls
import ManagedSettings
import SwiftUI

enum Theme {
    static let background = Color(red: 0.055, green: 0.067, blue: 0.086)
    static let surface = Color(red: 0.09, green: 0.106, blue: 0.133)
    static let surfaceHigh = Color(red: 0.13, green: 0.15, blue: 0.185)
    static let accent = Color(red: 0.506, green: 0.831, blue: 0.706)
    static let warm = Color(red: 0.96, green: 0.76, blue: 0.47)
    static let danger = Color(red: 0.94, green: 0.52, blue: 0.5)
    static let secondaryText = Color.white.opacity(0.62)
    static let tertiaryText = Color.white.opacity(0.4)
    static let corner: CGFloat = 22
}

extension View {
    /// Hebrew, right-to-left, dark. Applied at the root and on every modal.
    func regaEnvironment() -> some View {
        self
            .environment(\.layoutDirection, .rightToLeft)
            .environment(\.locale, Locale(identifier: "he_IL"))
            .preferredColorScheme(.dark)
            .tint(Theme.accent)
    }

    func card(padding: CGFloat = 18) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
    }

    func screenBackground() -> some View {
        self.background(Theme.background.ignoresSafeArea())
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = Theme.accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.title3, design: .rounded).weight(.semibold))
            .foregroundStyle(Theme.background)
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(color, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .rounded).weight(.medium))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Theme.surfaceHigh, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.callout, design: .rounded))
            .foregroundStyle(Theme.secondaryText)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

struct Chip: View {
    let title: String
    let symbol: String
    var selected = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
            Text(title)
        }
        .font(.system(.body, design: .rounded))
        .padding(.horizontal, 16)
        .frame(minHeight: 50)
        .frame(maxWidth: .infinity)
        .background(
            selected ? Theme.accent.opacity(0.22) : Theme.surfaceHigh,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(selected ? Theme.accent : .clear, lineWidth: 1.5)
        )
    }
}

struct SectionTitle: View {
    let text: LocalizedStringKey

    init(_ text: LocalizedStringKey) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(.footnote, design: .rounded).weight(.semibold))
            .foregroundStyle(Theme.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Opaque token rendered by the system (we never see the app's name ourselves).
struct TargetLabel: View {
    let target: ShieldTarget

    var body: some View {
        if let token = TokenCoding.applicationToken(target) {
            Label(token)
        } else if let token = TokenCoding.categoryToken(target) {
            Label(token)
        } else if let token = TokenCoding.webDomainToken(target) {
            Label(token)
        } else {
            Label("האפליקציה", systemImage: "app.dashed")
        }
    }
}

struct StrictNotice: View {
    var body: some View {
        Label("בזמן נעילה קשיחה אי אפשר להחליש הגנות. אפשר רק להקשיח.", systemImage: "lock.shield")
            .font(.footnote)
            .foregroundStyle(Theme.warm)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension Intention {
    var title: String {
        switch self {
        case .message: return String(localized: "הודעה מסוימת")
        case .lookup: return String(localized: "לבדוק משהו")
        case .work: return String(localized: "עבודה")
        case .boredom: return String(localized: "שעמום")
        case .habit: return String(localized: "סתם הרגל")
        }
    }

    var symbol: String {
        switch self {
        case .message: return "bubble.left"
        case .lookup: return "magnifyingglass"
        case .work: return "briefcase"
        case .boredom: return "cloud"
        case .habit: return "arrow.triangle.2.circlepath"
        }
    }
}

extension Date {
    /// Minutes after midnight for clock-time pickers.
    var minuteOfDay: Int {
        let c = Calendar.rega.dateComponents([.hour, .minute], from: self)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    static func fromMinuteOfDay(_ minutes: Int) -> Date {
        Calendar.rega.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) ?? Date()
    }
}

extension Binding where Value == Int {
    /// Bridges a "minutes after midnight" value to a DatePicker.
    var asClockDate: Binding<Date> {
        Binding<Date>(
            get: { Date.fromMinuteOfDay(wrappedValue) },
            set: { wrappedValue = $0.minuteOfDay }
        )
    }
}
