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
    /// Pill centre while the finger is on the bar; nil when resting on the selected tab.
    @State private var dragX: CGFloat?
    @State private var hoveredTab: Tab?

    enum Tab: String, CaseIterable {
        case dashboard = "Home"
        case map       = "Map"
        case stats     = "Stats"
        case goals     = "Goals"
        case notes     = "Notes"

        /// Outline when idle, filled when selected (like the system tab bars).
        func symbol(selected: Bool) -> String {
            switch self {
            case .dashboard: return selected ? "house.fill" : "house"
            case .map:       return selected ? "map.fill" : "map"
            case .stats:     return selected ? "chart.bar.fill" : "chart.bar"
            case .goals:     return selected ? "flag.fill" : "flag"
            case .notes:     return selected ? "doc.text.fill" : "doc.text"
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
                    .padding(.horizontal, 28)
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

    /// Apple Music–style bar: tap a tab, or press and slide. The pill follows the
    /// finger like a lens, the tab under it lights up, and it snaps on release.
    private var glassTabBar: some View {
        GeometryReader { geo in
            let tabs = Tab.allCases
            let tabW = geo.size.width / CGFloat(tabs.count)
            let selectedIndex = CGFloat(tabs.firstIndex(of: selectedTab) ?? 0)
            let restingX = tabW * (selectedIndex + 0.5)
            let pillX = dragX ?? restingX
            let isDragging = dragX != nil
            let highlighted = hoveredTab ?? selectedTab

            ZStack(alignment: .leading) {
                // Selection pill (lens)
                Capsule()
                    .fill(Color.textPrimary.opacity(isDragging ? 0.16 : 0.10))
                    .frame(width: tabW - 4, height: geo.size.height)
                    .scaleEffect(isDragging ? 1.12 : 1)
                    .position(x: pillX, y: geo.size.height / 2)
                    .animation(isDragging ? .interactiveSpring(response: 0.18, dampingFraction: 0.86)
                                          : .spring(response: 0.42, dampingFraction: 0.78), value: pillX)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDragging)

                HStack(spacing: 0) {
                    ForEach(tabs, id: \.self) { tab in
                        let lit = highlighted == tab
                        VStack(spacing: 3) {
                            Image(systemName: tab.symbol(selected: lit))
                                .font(.system(size: 19, weight: .medium))
                                .frame(height: 22)
                            Text(tab.rawValue)
                                .font(.system(size: 10, weight: lit ? .semibold : .medium))
                        }
                        .foregroundStyle(lit ? Color.heroPink : Color.textSecondary)
                        .scaleEffect(lit && isDragging ? 1.08 : 1)
                        .frame(width: tabW, height: geo.size.height)
                        .contentShape(Rectangle())
                        .animation(.easeOut(duration: 0.15), value: lit)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(tab.rawValue)
                        .accessibilityAddTraits(selectedTab == tab ? [.isButton, .isSelected] : .isButton)
                        .accessibilityAction { select(tab) }
                    }
                }
            }
            .contentShape(Capsule())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let x = min(max(value.location.x, tabW / 2), geo.size.width - tabW / 2)
                        // Only start the lens once the finger actually moves (a tap stays a tap).
                        if dragX != nil || abs(value.translation.width) > 4 {
                            dragX = x
                        }
                        let tab = tabs[min(max(Int(value.location.x / tabW), 0), tabs.count - 1)]
                        if tab != hoveredTab {
                            if hoveredTab != nil { Haptics.light() }
                            hoveredTab = tab
                        }
                    }
                    .onEnded { value in
                        let tab = tabs[min(max(Int(value.location.x / tabW), 0), tabs.count - 1)]
                        select(tab)
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                            dragX = nil
                            hoveredTab = nil
                        }
                    }
            )
        }
        .frame(height: 56)
        .padding(5)
        .glassEffect(.regular.interactive(), in: .capsule)
    }

    private func select(_ tab: Tab) {
        guard tab != selectedTab else { return }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) { selectedTab = tab }
        Haptics.light()
    }
}
