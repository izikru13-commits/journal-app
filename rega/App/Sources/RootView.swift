import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    private let ticker = Timer.publish(every: 20, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if let screen = DemoMode.screen {
                DemoScreen(screen: screen)
            } else if !model.settings.onboardingCompleted {
                OnboardingView()
            } else {
                MainTabs()
            }
        }
        .regaEnvironment()
        .fullScreenCover(item: $model.intervention) { request in
            InterventionView(request: request)
                .environmentObject(model)
                .regaEnvironment()
        }
        .sheet(isPresented: $model.showUnlock) {
            UnlockView()
                .environmentObject(model)
                .regaEnvironment()
        }
        .alert(
            "רגע",
            isPresented: Binding(get: { model.alert != nil }, set: { if !$0 { model.alert = nil } }),
            actions: { Button("הבנתי") { model.alert = nil } },
            message: { Text(model.alert ?? "") }
        )
        .onReceive(ticker) { _ in
            // Foreground safety net: re-shields expired openings within seconds.
            if !DemoMode.isActive { model.refresh() }
        }
    }
}

struct MainTabs: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        TabView(selection: $model.tab) {
            NavigationStack { HomeView() }
                .tabItem { Label("בית", systemImage: "wind") }
                .tag(MainTab.home)
            NavigationStack { LocksView() }
                .tabItem { Label("נעילות", systemImage: "lock") }
                .tag(MainTab.locks)
            NavigationStack { StatsView() }
                .tabItem { Label("נתונים", systemImage: "chart.bar") }
                .tag(MainTab.stats)
            NavigationStack { SettingsView() }
                .tabItem { Label("הגדרות", systemImage: "gearshape") }
                .tag(MainTab.settings)
        }
    }
}
