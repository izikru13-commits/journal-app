import FamilyControls
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    private func binding<T>(_ keyPath: WritableKeyPath<RegaSettings, T>) -> Binding<T> {
        Binding(
            get: { model.settings[keyPath: keyPath] },
            set: { value in model.updateSettings { $0[keyPath: keyPath] = value } }
        )
    }

    var body: some View {
        let s = model.settings
        let strict = !model.canWeaken
        Form {
            if strict {
                Section { StrictNotice() }
            }

            Section {
                Toggle("השער פעיל", isOn: binding(\.gateEnabled))
                    .disabled(strict && s.gateEnabled)
                NavigationLink("אפליקציות מסיחות (\(model.distractionCount))") { DistractionsView() }
                Stepper("המתנה בסיסית: \(s.delayBaseSeconds) שנ׳", value: binding(\.delayBaseSeconds), in: (strict ? s.delayBaseSeconds : 3)...30)
                Stepper("תוספת לכל פתיחה: \(s.delayStepSeconds) שנ׳", value: binding(\.delayStepSeconds), in: (strict ? s.delayStepSeconds : 0)...20)
                Stepper("המתנה מקסימלית: \(s.delayMaxSeconds) שנ׳", value: binding(\.delayMaxSeconds), in: (strict ? s.delayMaxSeconds : 10)...120, step: 5)
                Stepper("יעד: עד \(s.dailyApprovedGoal) פתיחות ביום", value: binding(\.dailyApprovedGoal), in: 0...30)
            } header: {
                Text("השער")
            } footer: {
                Text("לפני כל פתיחה יש נשימה. היום היא \(DelayPolicy.seconds(approvedToday: model.today.approved, settings: s)) שניות, והיא מתארכת עם כל פתיחה מאושרת.")
            }

            Section {
                Toggle("תקציב יומי", isOn: binding(\.budgetEnabled))
                    .disabled(strict && s.budgetEnabled)
                if s.budgetEnabled {
                    Stepper("\(s.budgetMinutes) דקות ביום", value: binding(\.budgetMinutes), in: 5...(strict ? s.budgetMinutes : 240), step: 5)
                }
            } header: {
                Text("תקציב יומי · ניסיוני")
            } footer: {
                Text("תלוי באמינות של iOS. התראה ב-80%, ובמאה אחוז האפליקציות המסיחות ננעלות עד חצות. הנעילה הזו אף פעם לא קשיחה, כי לפעמים iOS מדווחת בטעות.")
            }

            Section {
                NavigationLink("המפתח הפיזי") { KeySetupView() }
                Toggle("למנוע מחיקת אפליקציות בזמן נעילה קשיחה", isOn: binding(\.denyAppRemovalDuringStrict))
                    .disabled(strict && s.denyAppRemovalDuringStrict)
            } header: {
                Text("נעילות")
            } footer: {
                Text("כך אי אפשר למחוק את רגע כדי לברוח מנעילה. בזמן הנעילה iOS לא תאפשר למחוק אף אפליקציה.")
            }

            Section("התראות") {
                Toggle("סיכום ערב", isOn: binding(\.eveningSummaryEnabled))
                if s.eveningSummaryEnabled {
                    DatePicker("שעה", selection: binding(\.eveningSummaryMinute).asClockDate, displayedComponents: .hourAndMinute)
                }
                Toggle("סיכום שבועי (ראשון ב-20:00)", isOn: binding(\.weeklySummaryEnabled))
                if !model.notificationsAuthorized {
                    Button("לאפשר התראות") { Task { await model.requestNotifications() } }
                }
            }

            Section("במקום הטלפון") {
                NavigationLink("דברים לעשות במקום") { ReplacementsEditor() }
                NavigationLink("טיפים שעובדים") { TipsView(showsDone: false) }
            }

            Section {
                HStack {
                    Text("Screen Time")
                    Spacer()
                    Text(model.isAuthorized ? "מאושר" : "לא מאושר")
                        .foregroundStyle(model.isAuthorized ? Theme.accent : Theme.warm)
                }
                Button("אישור Screen Time מחדש") { Task { await model.requestScreenTime() } }
                Button("לתזמן מחדש את כל הנעילות") { model.resyncSchedules() }
            } header: {
                Text("מערכת")
            } footer: {
                Text("כל המידע נשאר במכשיר. אין שרת, אין חשבון, אין אנליטיקס.")
            }
        }
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle("הגדרות")
    }
}

struct ReplacementsEditor: View {
    @EnvironmentObject private var model: AppModel
    @State private var list: [ReplacementActivity] = []
    @State private var newTitle = ""

    var body: some View {
        List {
            Section {
                ForEach($list) { $item in
                    HStack {
                        Image(systemName: item.symbol)
                            .foregroundStyle(Theme.accent)
                            .frame(width: 28)
                        TextField("פעילות", text: $item.title)
                    }
                }
                .onDelete { list.remove(atOffsets: $0) }
                .onMove { list.move(fromOffsets: $0, toOffset: $1) }
            } footer: {
                Text("כשתבחר ״שעמום״ או ״סתם הרגל״, רגע יציע אחת מאלה לפני שהוא פותח.")
            }
            Section {
                HStack {
                    TextField("פעילות חדשה", text: $newTitle)
                    Button("הוספה") {
                        let title = newTitle.trimmingCharacters(in: .whitespaces)
                        guard !title.isEmpty else { return }
                        list.append(ReplacementActivity(title: title, symbol: "sparkles"))
                        newTitle = ""
                    }
                    .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                Button("שחזור ברירת המחדל") { list = ReplacementActivity.defaults }
            }
        }
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle("דברים לעשות במקום")
        .toolbar { EditButton() }
        .onAppear { list = model.replacements }
        .onChange(of: list) { _, value in model.saveReplacements(value) }
    }
}
