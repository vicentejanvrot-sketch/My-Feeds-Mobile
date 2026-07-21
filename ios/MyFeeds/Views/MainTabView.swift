import SwiftUI

/// Navigation destinations pushed within tabs.
enum AppRoute: Hashable {
    case agentDetail(String)
    case agentForm(String?)
    case faq
    case privacy
    case terms
}

struct MainTabView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            NavigationStack {
                DashboardView()
                    .withAppRoutes()
            }
            .tabItem { Label("Dashboard", systemImage: "square.grid.2x2") }
            .tag(AppTab.dashboard)

            NavigationStack {
                AgentsView()
                    .withAppRoutes()
            }
            .tabItem { Label("Agents", systemImage: "cpu") }
            .tag(AppTab.agents)

            NavigationStack {
                FeedView()
                    .withAppRoutes()
            }
            .tabItem { Label("Feed", systemImage: "dot.radiowaves.right") }
            .tag(AppTab.feed)

            NavigationStack {
                HistoryView()
                    .withAppRoutes()
            }
            .tabItem { Label("History", systemImage: "clock") }
            .tag(AppTab.history)

            NavigationStack {
                SettingsView()
                    .withAppRoutes()
            }
            .tabItem { Label("Settings", systemImage: "gearshape") }
            .tag(AppTab.settings)
        }
        .tint(Theme.accent)
    }
}

private struct AppRoutesModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .agentDetail(let agentId):
                    AgentDetailView(agentId: agentId)
                case .agentForm(let agentId):
                    AgentFormView(agentId: agentId)
                case .faq:
                    FAQView()
                case .privacy:
                    PrivacyPolicyView()
                case .terms:
                    TermsView()
                }
            }
    }
}

extension View {
    func withAppRoutes() -> some View {
        modifier(AppRoutesModifier())
    }
}
