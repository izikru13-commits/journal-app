import Charts
import DeviceActivity
import SwiftUI

extension DeviceActivityReport.Context {
    static let today = Self("today")
    static let week = Self("week")
}

struct StatsView: View {
    @EnvironmentObject private var model: AppModel

    private var days: [DayStat] { StatsMath.lastDays(14, counters: model.counters, today: Date()) }
    private var week: DayCounters { StatsMath.total(Array(days.suffix(7))) }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                hero
                streakCard
                attemptsChart
                rateChart
                minutesChart
                intentionCard
                screenTime
            }
            .padding(18)
        }
        .screenBackground()
        .navigationTitle("נתונים")
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("אחוז ויתור · 7 ימים")
            HStack(alignment: .center, spacing: 20) {
                DismissRing(rate: week.dismissRate, lineWidth: 14)
                    .frame(width: 130, height: 130)
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(week.attempts) ניסיונות")
                    Text("\(week.attempts - week.approved < 0 ? 0 : week.attempts - week.approved) לא נפתחו")
                        .foregroundStyle(Theme.accent)
                    Text("\(week.approved) פתיחות · \(week.approvedMinutes) דק׳")
                        .foregroundStyle(Theme.secondaryText)
                }
                .font(.system(.body, design: .rounded))
            }
            Text("זה המדד החשוב: כמה פעמים הדחף הגיע ועבר בלי לפתוח.")
                .font(.footnote)
                .foregroundStyle(Theme.tertiaryText)
        }
        .card()
    }

    private var streakCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "flame.fill")
                .font(.system(size: 34))
                .foregroundStyle(Theme.warm)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(model.streak) ימים ברצף")
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                Text("ימים עם עד \(model.settings.dailyApprovedGoal) פתיחות מאושרות")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .card()
    }

    private var attemptsChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("ניסיונות ביום")
            Chart {
                ForEach(days) { day in
                    BarMark(x: .value("יום", day.day, unit: .day), y: .value("ניסיונות", day.counters.attempts))
                        .foregroundStyle(by: .value("סוג", String(localized: "ניסיונות")))
                        .cornerRadius(4)
                    BarMark(x: .value("יום", day.day, unit: .day), y: .value("פתיחות", day.counters.approved))
                        .foregroundStyle(by: .value("סוג", String(localized: "פתיחות")))
                        .cornerRadius(4)
                }
            }
            .chartForegroundStyleScale([
                String(localized: "ניסיונות"): Theme.surfaceHigh,
                String(localized: "פתיחות"): Theme.warm,
            ])
            .chartXAxis { dayAxis }
            .frame(height: 170)
        }
        .card()
    }

    private var rateChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("אחוז ויתור לאורך זמן")
            Chart(days.filter { $0.counters.dismissRate != nil }) { day in
                LineMark(x: .value("יום", day.day, unit: .day), y: .value("אחוז", (day.counters.dismissRate ?? 0) * 100))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Theme.accent)
                PointMark(x: .value("יום", day.day, unit: .day), y: .value("אחוז", (day.counters.dismissRate ?? 0) * 100))
                    .foregroundStyle(Theme.accent)
            }
            .chartYScale(domain: 0...100)
            .chartXAxis { dayAxis }
            .frame(height: 150)
        }
        .card()
    }

    private var minutesChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("דקות מאושרות ביום")
            Chart(days) { day in
                BarMark(x: .value("יום", day.day, unit: .day), y: .value("דקות", day.counters.approvedMinutes))
                    .foregroundStyle(Theme.accent.gradient)
                    .cornerRadius(4)
            }
            .chartXAxis { dayAxis }
            .frame(height: 140)
        }
        .card()
    }

    private var intentionCard: some View {
        let since = Calendar.rega.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let top = StatsMath.topIntention(model.events, since: since)
        return HStack(spacing: 14) {
            Image(systemName: top?.symbol ?? "questionmark.bubble")
                .font(.title)
                .foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("הסיבה הנפוצה לפתיחה השבוע")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
                Text(top?.title ?? String(localized: "עוד אין מספיק נתונים"))
                    .font(.headline)
            }
        }
        .card()
    }

    private var screenTime: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("זמן מסך (מ-Screen Time)")
            DeviceActivityReport(.today, filter: filter(days: 1))
                .frame(minHeight: 340)
            DeviceActivityReport(.week, filter: filter(days: 7))
                .frame(minHeight: 260)
            Text("הנתונים האלה מוצגים ישירות מ-iOS ולא יוצאים מהמכשיר.")
                .font(.footnote)
                .foregroundStyle(Theme.tertiaryText)
        }
    }

    private func filter(days: Int) -> DeviceActivityFilter {
        let calendar = Calendar.rega
        let end = Date()
        let start = calendar.date(byAdding: .day, value: -(days - 1), to: calendar.startOfDay(for: end)) ?? end
        return DeviceActivityFilter(
            segment: .daily(during: DateInterval(start: start, end: end)),
            users: .all,
            devices: .init([.iPhone])
        )
    }

    @AxisContentBuilder private var dayAxis: some AxisContent {
        AxisMarks(values: .stride(by: .day, count: 2)) { _ in
            AxisValueLabel(format: .dateTime.day().month(.defaultDigits))
        }
    }
}
