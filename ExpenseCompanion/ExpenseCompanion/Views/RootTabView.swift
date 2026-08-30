//
//  RootTabView.swift
//  ExpenseCompanion
//

import SwiftUI
import SwiftData

struct RootTabView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab: Tab = .dashboard

    enum Tab: String, CaseIterable {
        case dashboard = "Home"
        case map = "Map"
        case stats = "Stats"
        case goals = "Goals"
        case settings = "Settings"

        var symbol: String {
            switch self {
            case .dashboard: return "house.fill"
            case .map: return "map.fill"
            case .stats: return "chart.pie.fill"
            case .goals: return "target"
            case .settings: return "gearshape.fill"
            }
        }
    }

    var body: some View {
        ZStack {
            DynamicGradientBackground()

            TabView(selection: $selectedTab) {
                DashboardView()
                    .tag(Tab.dashboard)
                    .toolbar(.hidden, for: .tabBar)

                MapExpensesView()
                    .tag(Tab.map)
                    .toolbar(.hidden, for: .tabBar)

                StatsView()
                    .tag(Tab.stats)
                    .toolbar(.hidden, for: .tabBar)

                GoalsListView()
                    .tag(Tab.goals)
                    .toolbar(.hidden, for: .tabBar)

                SettingsView()
                    .tag(Tab.settings)
                    .toolbar(.hidden, for: .tabBar)
            }

            VStack {
                Spacer()
                customTabBar
            }
        }
    }

    private var customTabBar: some View {
        HStack {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        selectedTab = tab
                    }
                    Haptics.light()
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 20, weight: selectedTab == tab ? .bold : .regular))
                            .scaleEffect(selectedTab == tab ? 1.1 : 1.0)
                            .foregroundStyle(selectedTab == tab ? Color.accentColor : Color.primary.opacity(0.35))

                        Text(tab.rawValue)
                            .font(.system(size: 10, weight: selectedTab == tab ? .semibold : .regular))
                            .foregroundStyle(selectedTab == tab ? Color.accentColor : Color.primary.opacity(0.35))

                        // Selected indicator dot
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 4, height: 4)
                            .opacity(selectedTab == tab ? 1 : 0)
                            .scaleEffect(selectedTab == tab ? 1 : 0.1)
                    }
                    .frame(maxWidth: .infinity)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedTab)
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .glassCard(cornerRadius: 28, padding: 6)
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }
}
