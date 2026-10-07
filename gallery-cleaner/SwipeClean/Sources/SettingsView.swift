import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: ProgressStore
    @EnvironmentObject private var library: PhotoLibraryService
    @Environment(\.dismiss) private var dismiss
    @State private var confirmReset = false

    private let goals = [20, 30, 50, 100, 200]

    var body: some View {
        NavigationStack {
            Form {
                Section("יעד יומי") {
                    Picker("פריטים ביום", selection: binding(\.dailyGoal)) {
                        ForEach(goals, id: \.self) { g in
                            Text("\(g) (כ-\(max(1, g * 6 / 60)) דק׳)").tag(g)
                        }
                    }
                }

                Section {
                    Toggle("תזכורת יומית", isOn: binding(\.reminderEnabled))
                    if store.data.reminderEnabled {
                        DatePicker("שעה", selection: reminderTime, displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text("תזכורת")
                } footer: {
                    Text("בשעה שנוחה לך: ״הגיע הזמן לנקות!״")
                }

                Section("סדר") {
                    Picker("להתחיל מ־", selection: binding(\.newestFirst)) {
                        Text("הישנות ביותר").tag(false)
                        Text("החדשות ביותר").tag(true)
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Button("איפוס ההתקדמות", role: .destructive) { confirmReset = true }
                } footer: {
                    Text("מוחק את רשימת הפריטים שכבר נסקרו, הרצף והסטטיסטיקות. לא מוחק שום תמונה.")
                }

                Section("איך זה עובד") {
                    Label("ימינה – לשמור", systemImage: "arrow.right")
                    Label("שמאלה – למחיקה", systemImage: "arrow.left")
                    Label("למעלה – למועדפים", systemImage: "arrow.up")
                    Label("המחיקה קורית רק בסוף, אחרי אישור שלך", systemImage: "checkmark.shield")
                    Label("פריטים שנמחקו נשארים 30 יום ב״נמחקו לאחרונה״", systemImage: "trash")
                }
            }
            .navigationTitle("הגדרות")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("סגור") { dismiss() }
                }
            }
            .confirmationDialog("לאפס את כל ההתקדמות?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("איפוס", role: .destructive) { store.resetProgress(); reschedule() }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func binding<T>(_ keyPath: WritableKeyPath<ProgressData, T>) -> Binding<T> {
        Binding(
            get: { store.data[keyPath: keyPath] },
            set: { value in
                store.update { $0[keyPath: keyPath] = value }
                reschedule()
            }
        )
    }

    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: store.data.reminderHour, minute: store.data.reminderMinute,
                                      second: 0, of: Date()) ?? Date()
            },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                store.update {
                    $0.reminderHour = c.hour ?? 20
                    $0.reminderMinute = c.minute ?? 0
                }
                reschedule()
            }
        )
    }

    private func reschedule() {
        if store.data.reminderEnabled {
            Task { _ = await NotificationManager.requestPermission() }
        }
        NotificationManager.reschedule(enabled: store.data.reminderEnabled,
                                       hour: store.data.reminderHour,
                                       minute: store.data.reminderMinute,
                                       goal: store.data.dailyGoal,
                                       remaining: library.remaining[.all] ?? store.data.dailyGoal,
                                       todayDone: store.todayDone)
    }
}
