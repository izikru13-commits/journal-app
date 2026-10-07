import Charts
import DeviceActivity
import ManagedSettings
import SwiftUI

/// Screen Time data cannot leave this extension, so the usage dashboard is rendered here
/// and embedded in the app with `DeviceActivityReport`.
@main
struct RegaReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        TodayReport { summary in
            TodayReportView(summary: summary)
        }
        WeekReport { days in
            WeekReportView(days: days)
        }
    }
}

extension DeviceActivityReport.Context {
    static let today = Self("today")
    static let week = Self("week")
}

struct AppUsage: Identifiable {
    var id: String
    var token: ApplicationToken?
    var name: String
    var duration: TimeInterval
    var pickups: Int
}

struct UsageSummary {
    var total: TimeInterval = 0
    var pickups = 0
    var topApps: [AppUsage] = []
}

struct DayUsage: Identifiable {
    var day: Date
    var total: TimeInterval
    var id: Date { day }
}

struct TodayReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .today
    let content: (UsageSummary) -> TodayReportView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> UsageSummary {
        var summary = UsageSummary()
        var apps: [String: AppUsage] = [:]
        for await datum in data {
            for await segment in datum.activitySegments {
                summary.total += segment.totalActivityDuration
                summary.pickups += segment.totalPickupsWithoutApplicationActivity
                for await category in segment.categories {
                    for await activity in category.applications {
                        let app = activity.application
                        let name = app.localizedDisplayName ?? app.bundleIdentifier ?? "אפליקציה"
                        let key = app.bundleIdentifier ?? name
                        var usage = apps[key] ?? AppUsage(id: key, token: app.token, name: name, duration: 0, pickups: 0)
                        usage.duration += activity.totalActivityDuration
                        usage.pickups += activity.numberOfPickups
                        apps[key] = usage
                        summary.pickups += activity.numberOfPickups
                    }
                }
            }
        }
        summary.topApps = Array(apps.values.sorted { $0.duration > $1.duration }.prefix(6))
        return summary
    }
}

struct WeekReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .week
    let content: ([DayUsage]) -> WeekReportView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> [DayUsage] {
        var totals: [Date: TimeInterval] = [:]
        let calendar = Calendar.rega
        for await datum in data {
            for await segment in datum.activitySegments {
                let day = calendar.startOfDay(for: segment.dateInterval.start)
                totals[day, default: 0] += segment.totalActivityDuration
            }
        }
        return totals.map { DayUsage(day: $0.key, total: $0.value) }.sorted { $0.day < $1.day }
    }
}

// MARK: - Views

private enum ReportPalette {
    static let surface = Color(red: 0.09, green: 0.106, blue: 0.133)
    static let accent = Color(red: 0.506, green: 0.831, blue: 0.706)
    static let secondary = Color.white.opacity(0.6)
}

struct TodayReportView: View {
    let summary: UsageSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("זמן מסך היום")
                        .font(.subheadline)
                        .foregroundStyle(ReportPalette.secondary)
                    Text(DurationText.short(summary.total))
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("הרמות")
                        .font(.subheadline)
                        .foregroundStyle(ReportPalette.secondary)
                    Text("\(summary.pickups)")
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                }
            }
            if summary.topApps.isEmpty {
                Text("עוד אין נתונים להיום.")
                    .foregroundStyle(ReportPalette.secondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(summary.topApps) { app in
                        HStack {
                            if let token = app.token {
                                Label(token)
                                    .labelStyle(.titleAndIcon)
                                    .lineLimit(1)
                            } else {
                                Text(app.name).lineLimit(1)
                            }
                            Spacer()
                            Text(DurationText.short(app.duration))
                                .monospacedDigit()
                                .foregroundStyle(ReportPalette.secondary)
                        }
                        .font(.callout)
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ReportPalette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .foregroundStyle(.white)
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.locale, Locale(identifier: "he_IL"))
    }
}

struct WeekReportView: View {
    let days: [DayUsage]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("זמן מסך ב-7 הימים האחרונים")
                .font(.subheadline)
                .foregroundStyle(ReportPalette.secondary)
            if days.isEmpty {
                Text("עוד אין נתונים.")
                    .foregroundStyle(ReportPalette.secondary)
            } else {
                Chart(days) { day in
                    BarMark(
                        x: .value("יום", day.day, unit: .day),
                        y: .value("שעות", day.total / 3600)
                    )
                    .foregroundStyle(ReportPalette.accent.gradient)
                    .cornerRadius(6)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.narrow))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine().foregroundStyle(.white.opacity(0.08))
                        AxisValueLabel {
                            if let hours = value.as(Double.self) {
                                Text("\(Int(hours)) ש׳")
                            }
                        }
                    }
                }
                .frame(height: 160)
                let average = days.map(\.total).reduce(0, +) / Double(max(days.count, 1))
                Text("ממוצע יומי: \(DurationText.short(average))")
                    .font(.footnote)
                    .foregroundStyle(ReportPalette.secondary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ReportPalette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .foregroundStyle(.white)
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.locale, Locale(identifier: "he_IL"))
    }
}
