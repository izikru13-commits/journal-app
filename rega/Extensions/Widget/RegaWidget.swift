import SwiftUI
import WidgetKit

@main
struct RegaWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayWidget()
    }
}

struct TodayEntry: TimelineEntry {
    var date: Date
    var counters: DayCounters
    var locked: Bool
    var nudge: String
}

struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEntry {
        TodayEntry(date: Date(), counters: DayCounters(attempts: 6, dismissed: 4, approved: 2, approvedMinutes: 10), locked: false, nudge: WidgetNudges.pick(DayCounters(), date: Date()))
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : entry(at: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        let now = Date()
        let calendar = Calendar.rega
        let refresh = now.addingTimeInterval(15 * 60)
        let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? refresh
        var entries = [entry(at: now)]
        if midnight < refresh {
            entries.append(TodayEntry(date: midnight, counters: DayCounters(), locked: false, nudge: WidgetNudges.pick(DayCounters(), date: midnight)))
        }
        completion(Timeline(entries: entries, policy: .after(min(refresh, midnight.addingTimeInterval(60)))))
    }

    private func entry(at date: Date) -> TodayEntry {
        let store = SharedStore.shared
        let counters = store.counters(for: date)
        let protection = ProtectionEvaluator.evaluate(
            rules: store.locks, manual: store.manualSession, overrides: store.lockOverrides,
            budget: store.budget, settings: store.settings, now: date
        )
        return TodayEntry(date: date, counters: counters, locked: protection.isLocked, nudge: WidgetNudges.pick(counters, date: date))
    }
}

enum WidgetNudges {
    static func pick(_ counters: DayCounters, date: Date) -> String {
        if counters.attempts == 0 { return String(localized: "יום שקט עד עכשיו.") }
        if (counters.dismissRate ?? 0) >= 0.6 { return String(localized: "אתה מוותר יותר משאתה פותח. יפה.") }
        let lines = [
            String(localized: "הדחף עובר. אפשר לחכות לו."),
            String(localized: "מה תעשה במקום?"),
            String(localized: "נשימה אחת לפני כל פתיחה."),
        ]
        let hour = Calendar.rega.component(.hour, from: date)
        return lines[hour % lines.count]
    }
}

struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "RegaToday", provider: TodayProvider()) { entry in
            TodayWidgetView(entry: entry)
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.locale, Locale(identifier: "he_IL"))
        }
        .configurationDisplayName("רגע – היום")
        .description("ניסיונות, ויתורים ופתיחות של היום.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}

private enum WidgetPalette {
    static let background = Color(red: 0.055, green: 0.067, blue: 0.086)
    static let accent = Color(red: 0.506, green: 0.831, blue: 0.706)
}

struct TodayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TodayEntry

    var body: some View {
        content
            .containerBackground(for: .widget) {
                WidgetPalette.background
            }
    }

    @ViewBuilder private var content: some View {
        let c = entry.counters
        switch family {
        case .accessoryInline:
            Text("רגע: \(c.dismissed) ויתורים · \(c.approved) פתיחות")
        case .accessoryCircular:
            Gauge(value: c.dismissRate ?? 0) {
                Image(systemName: "wind")
            } currentValueLabel: {
                Text("\(c.dismissed)")
            }
            .gaugeStyle(.accessoryCircularCapacity)
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text("רגע.").font(.headline)
                Text("\(c.attempts) ניסיונות · \(c.dismissed) ויתורים")
                Text("\(c.approved) פתיחות מאושרות")
            }
            .font(.caption)
        case .systemMedium:
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    header
                    Spacer(minLength: 0)
                    Text(entry.nudge)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                HStack(spacing: 14) {
                    stat("\(c.attempts)", "ניסיונות")
                    stat("\(c.dismissed)", "ויתורים", highlight: true)
                    stat("\(c.approved)", "פתיחות")
                }
            }
            .foregroundStyle(.white)
        default:
            VStack(alignment: .leading, spacing: 8) {
                header
                Spacer(minLength: 0)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(c.dismissed)")
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .foregroundStyle(WidgetPalette.accent)
                    Text("ויתורים")
                        .font(.caption)
                }
                Text("\(c.attempts) ניסיונות · \(c.approved) פתיחות")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: entry.locked ? "lock.fill" : "wind")
                .foregroundStyle(WidgetPalette.accent)
            Text("רגע.")
                .font(.headline)
        }
    }

    private func stat(_ value: String, _ label: LocalizedStringKey, highlight: Bool = false) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 26, weight: .semibold, design: .rounded))
                .foregroundStyle(highlight ? WidgetPalette.accent : .white)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}
