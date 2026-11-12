//
//  RootTabView.swift
//  ExpenseCompanion
//
//  Theme-controlled root. Reads @AppStorage("appTheme") and applies
//  preferredColorScheme to the whole app — all sub-views inherit it.
//  Liquid glass pill tab bar adapts to light / dark automatically.
//

import SwiftUI
import SwiftData

struct RootTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("appTheme") private var appTheme: AppTheme = .dark

    @State private var selectedTab: Tab = .dashboard
    @State private var blobLeadX: CGFloat = 0
    @State private var blobLeadXImmediate: CGFloat = 0

    enum Tab: String, CaseIterable {
        case dashboard = "Home"
        case map       = "Map"
        case stats     = "Stats"
        case goals     = "Goals"
        case notes     = "Notes"
        case settings  = "Settings"

        var symbol: String {
            switch self {
            case .dashboard: return "house.fill"
            case .map:       return "map.fill"
            case .stats:     return "chart.pie.fill"
            case .goals:     return "target"
            case .notes:     return "note.text"
            case .settings:  return "gearshape.fill"
            }
        }
    }

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

                SettingsView()
                    .tag(Tab.settings)
                    .toolbar(.hidden, for: .tabBar)
            }

            liquidTabBar
                .padding(.bottom, 22)
        }
        .ignoresSafeArea(edges: .bottom)
        // ── Single source of truth for the colour scheme ───────────────
        .preferredColorScheme(appTheme.colorScheme)
    }

    // MARK: - Liquid Glass Tab Bar

    private var liquidTabBar: some View {
        GeometryReader { geo in
            let w    = geo.size.width
            let tabW = w / CGFloat(Tab.allCases.count)
            let blobH: CGFloat = 44
            let isDark = colorScheme == .dark

            ZStack(alignment: .leading) {
                // Adaptive frosted pill background
                Capsule()
                    .fill(Color.cardSurface)
                    .shadow(color: .black.opacity(isDark ? 0.5 : 0.08), radius: 20, x: 0, y: 8)

                // Liquid gradient blob
                let leftCenter  = min(blobLeadX, blobLeadXImmediate)
                let rightCenter = max(blobLeadX, blobLeadXImmediate)
                let blobLeft  = leftCenter - blobH / 2
                let blobWidth = (rightCenter - leftCenter) + blobH

                RoundedRectangle(cornerRadius: blobH / 2, style: .continuous)
                    .fill(Color.textPrimary)
                    .frame(width: max(blobWidth, blobH), height: blobH)
                    .offset(x: blobLeft)
                    .animation(.spring(response: 0.45, dampingFraction: 0.62), value: blobLeadX)

                // Tab icons
                HStack(spacing: 0) {
                    ForEach(Array(Tab.allCases.enumerated()), id: \.element) { idx, tab in
                        let isSelected = selectedTab == tab
                        Button {
                            switchTab(to: tab, idx: idx, tabW: tabW)
                        } label: {
                            Image(systemName: tab.symbol)
                                .font(.system(size: 19, weight: isSelected ? .bold : .regular))
                                .foregroundStyle(isSelected ? Color.appBackground : Color.textTertiary)
                                .scaleEffect(isSelected ? 1.08 : 1.0)
                                .frame(width: tabW, height: geo.size.height)
                                .contentShape(Rectangle())
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(tab.rawValue)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
            }
            .onAppear {
                let idx = CGFloat(Tab.allCases.firstIndex(of: selectedTab) ?? 0)
                let center = tabW * idx + tabW / 2
                blobLeadX = center
                blobLeadXImmediate = center
            }
        }
        .frame(height: 60)
        .padding(.horizontal, 28)
    }

    private func switchTab(to tab: Tab, idx: Int, tabW: CGFloat) {
        guard tab != selectedTab else { return }
        let newCenter = tabW * CGFloat(idx) + tabW / 2
        blobLeadXImmediate = newCenter
        withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) {
            blobLeadX = newCenter
            selectedTab = tab
        }
        Haptics.light()
    }
}
