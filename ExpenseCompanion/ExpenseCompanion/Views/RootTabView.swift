//
//  RootTabView.swift
//  ExpenseCompanion
//
//  Theme-controlled root. Reads @AppStorage("appTheme") and applies
//  preferredColorScheme to the whole app. The floating tab bar uses Liquid
//  Glass and hides on detail screens and while the keyboard is up.
//

import SwiftUI
import SwiftData
import Observation

/// Lets detail screens hide the floating tab bar while they're on screen.
@Observable
final class TabBarVisibility {
    fileprivate var hiders = 0
    var isHidden: Bool { hiders > 0 }
}

private struct HidesTabBar: ViewModifier {
    @Environment(TabBarVisibility.self) private var visibility: TabBarVisibility?

    func body(content: Content) -> some View {
        content
            .onAppear { visibility?.hiders += 1 }
            .onDisappear { if let v = visibility { v.hiders = max(v.hiders - 1, 0) } }
    }
}

extension View {
    /// Hide the floating tab bar while this screen is visible.
    func hidesTabBar() -> some View { modifier(HidesTabBar()) }
}

struct RootTabView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("appTheme") private var appTheme: AppTheme = .dark

    @State private var selectedTab: Tab = .dashboard
    @State private var tabBar = TabBarVisibility()
    @State private var keyboardVisible = false
    @Namespace private var selection

    enum Tab: String, CaseIterable {
        case dashboard = "Home"
        case map       = "Map"
        case stats     = "Stats"
        case goals     = "Goals"
        case notes     = "Notes"

        var symbol: String {
            switch self {
            case .dashboard: return "house.fill"
            case .map:       return "map.fill"
            case .stats:     return "chart.pie.fill"
            case .goals:     return "target"
            case .notes:     return "note.text"
            }
        }
    }

    private var showsTabBar: Bool { !tabBar.isHidden && !keyboardVisible }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.appBackground.ignoresSafeArea()

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

                NotesListView()
                    .tag(Tab.notes)
                    .toolbar(.hidden, for: .tabBar)
            }
            .environment(tabBar)

            if showsTabBar {
                glassTabBar
                    .padding(.horizontal, 40)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .ignoresSafeArea(.keyboard)
        .ignoresSafeArea(edges: .bottom)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showsTabBar)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            keyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardVisible = false
        }
        // Single source of truth for the colour scheme
        .preferredColorScheme(appTheme.colorScheme)
    }

    // MARK: - Liquid Glass tab bar

    private var glassTabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                let isSelected = selectedTab == tab
                Button {
                    guard tab != selectedTab else { return }
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) { selectedTab = tab }
                    Haptics.light()
                } label: {
                    Image(systemName: tab.symbol)
                        .font(.system(size: 18, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? Color.appBackground : Color.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill(Color.textPrimary)
                                    .matchedGeometryEffect(id: "selected-tab", in: selection)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.rawValue)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(6)
        .glassEffect(.regular.interactive(), in: .capsule)
    }
}
