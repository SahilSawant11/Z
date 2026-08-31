//
//  RootTabView.swift
//  ExpenseCompanion
//
//  Liquid-glass pill tab bar. The selection indicator is a morphing blob
//  that "stretches" toward the new tab and snaps back — the rubber-band
//  water-drop effect seen in Apple Music on iOS 26.
//

import SwiftUI
import SwiftData

struct RootTabView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab: Tab = .dashboard

    // Liquid blob state
    @State private var blobLeadX: CGFloat = 0    // follows with spring (trailing edge)
    @State private var blobLeadXImmediate: CGFloat = 0  // jumps instantly (leading edge)
    @State private var barWidth: CGFloat = 0

    enum Tab: String, CaseIterable {
        case dashboard = "Home"
        case map = "Map"
        case stats = "Stats"
        case goals = "Goals"
        case settings = "Settings"

        var symbol: String {
            switch self {
            case .dashboard: return "house.fill"
            case .map:       return "map.fill"
            case .stats:     return "chart.pie.fill"
            case .goals:     return "target"
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

                SettingsView()
                    .tag(Tab.settings)
                    .toolbar(.hidden, for: .tabBar)
            }

            // Liquid glass tab bar
            liquidTabBar
                .padding(.bottom, 22)
        }
        .preferredColorScheme(.dark)
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Liquid Glass Tab Bar

    private var liquidTabBar: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let count = CGFloat(Tab.allCases.count)
            let tabW = w / count
            let blobH: CGFloat = 44

            ZStack(alignment: .leading) {
                // Frosted pill background
                Capsule()
                    .fill(Color(red: 0.10, green: 0.10, blue: 0.13).opacity(0.92))
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
                    .shadow(color: .black.opacity(0.55), radius: 22, x: 0, y: 8)

                // ── Liquid blob ─────────────────────────────────────────────
                // The blob spans from the slower-moving blobLeadX to the
                // instant-moving blobLeadXImmediate, creating a stretch effect.
                let leftCenter  = min(blobLeadX, blobLeadXImmediate)
                let rightCenter = max(blobLeadX, blobLeadXImmediate)
                let blobLeft   = leftCenter - blobH / 2
                let blobWidth  = (rightCenter - leftCenter) + blobH

                RoundedRectangle(cornerRadius: blobH / 2, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.heroPink, Color.heroPurple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(blobWidth, blobH), height: blobH)
                    .offset(x: blobLeft)
                    .shadow(color: Color.heroPink.opacity(0.55), radius: 14, x: 0, y: 4)
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
                                .foregroundStyle(isSelected ? .white : Color.white.opacity(0.32))
                                .scaleEffect(isSelected ? 1.08 : 1.0)
                                .frame(width: tabW, height: geo.size.height)
                                .contentShape(Rectangle())
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .onAppear {
                barWidth = w
                // Initialise blob at current tab
                let idx = CGFloat(Tab.allCases.firstIndex(of: selectedTab) ?? 0)
                let center = tabW * idx + tabW / 2
                blobLeadX = center
                blobLeadXImmediate = center
            }
        }
        .frame(height: 60)
        .padding(.horizontal, 28)
    }

    // MARK: - Tab Switch

    private func switchTab(to tab: Tab, idx: Int, tabW: CGFloat) {
        guard tab != selectedTab else { return }

        let newCenter = tabW * CGFloat(idx) + tabW / 2

        // Leading edge jumps immediately → creates the stretch
        blobLeadXImmediate = newCenter

        // Trailing edge follows with spring → snap back
        withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) {
            blobLeadX = newCenter
            selectedTab = tab
        }
        Haptics.light()
    }
}
