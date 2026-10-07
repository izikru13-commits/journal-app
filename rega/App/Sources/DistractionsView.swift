import FamilyControls
import ManagedSettings
import SwiftUI

struct DistractionsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showPicker = false
    @State private var draft = FamilyActivitySelection()

    var body: some View {
        List {
            Section {
                Button {
                    draft = model.distractions
                    showPicker = true
                } label: {
                    Label(model.distractionCount == 0 ? "בחירת אפליקציות מסיחות" : "עריכת הרשימה", systemImage: "plus.app")
                }
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    Text("אפשר לבחור אפליקציות, קטגוריות שלמות ואתרים. כולם יעברו דרך השער של רגע.")
                    Text("טיפ: אל תבחר קטגוריה שרגע עצמו נמצא בה (למשל ״פרודוקטיביות״), אחרת גם רגע יינעל.")
                    if !model.canWeaken {
                        Text("בזמן נעילה קשיחה אפשר רק להוסיף.")
                            .foregroundStyle(Theme.warm)
                    }
                }
            }

            let selection = model.distractions
            if !selection.applicationTokens.isEmpty {
                Section("אפליקציות") {
                    ForEach(Array(selection.applicationTokens), id: \.self) { token in
                        Label(token)
                    }
                }
            }
            if !selection.categoryTokens.isEmpty {
                Section("קטגוריות") {
                    ForEach(Array(selection.categoryTokens), id: \.self) { token in
                        Label(token)
                    }
                }
            }
            if !selection.webDomainTokens.isEmpty {
                Section("אתרים") {
                    ForEach(Array(selection.webDomainTokens), id: \.self) { token in
                        Label(token)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle("אפליקציות מסיחות")
        .familyActivityPicker(isPresented: $showPicker, selection: $draft)
        .onChange(of: showPicker) { _, isShowing in
            if !isShowing && draft != model.distractions {
                model.updateDistractions(draft)
            }
        }
    }
}
