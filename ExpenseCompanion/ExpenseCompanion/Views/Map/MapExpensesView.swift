//
//  MapExpensesView.swift
//  ExpenseCompanion
//
//  Dark fintech map tab. Full-screen map with GTA-V style dark vignette,
//  auto-zoom to current location, a safe-area-aware custom locate button,
//  and category filter chips with glow.
//

import SwiftUI
import MapKit
import SwiftData

struct MapExpensesView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var allExpenses: [Expense] = []
    @State private var cameraPosition: MapCameraPosition = .userLocation(followsHeading: false, fallback: .automatic)
    @State private var selectedCluster: LocationCluster?
    @State private var activeCategoryFilter: ExpenseCategory?

    private var filteredExpenses: [Expense] {
        guard let activeCategoryFilter else { return allExpenses }
        return allExpenses.filter { $0.category == activeCategoryFilter }
    }

    private var clusters: [LocationCluster] {
        LocationInsightsEngine.clusterExpenses(filteredExpenses)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {

                // ── Full-screen map ────────────────────────────────────────
                Map(position: $cameraPosition, selection: .constant(nil)) {
                    UserAnnotation()
                    ForEach(clusters) { cluster in
                        Annotation(cluster.displayName, coordinate: cluster.coordinate) {
                            ClusterPinView(cluster: cluster)
                                .onTapGesture {
                                    selectedCluster = cluster
                                    Haptics.light()
                                }
                        }
                    }
                }
                .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .including([.restaurant, .cafe, .store])))
                .mapControls { MapCompass(); MapScaleView() }
                .ignoresSafeArea()

                // ── GTA V dark vignette ────────────────────────────────────
                // Dark radial gradient — heavy at edges, clear at center
                RadialGradient(
                    colors: [Color.clear, Color.black.opacity(0.68)],
                    center: .center,
                    startRadius: 100,
                    endRadius: 480
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)

                // Top fade (protects header readability)
                VStack {
                    LinearGradient(
                        colors: [Color.black.opacity(0.72), Color.clear],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: 160)
                    .ignoresSafeArea(edges: .top)
                    Spacer()
                    // Bottom fade (protects tab bar area)
                    LinearGradient(
                        colors: [Color.clear, Color.black.opacity(0.55)],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: 130)
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)

                // ── Floating top bar ───────────────────────────────────────
                VStack(spacing: 0) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("MAP")
                                .font(.system(size: 10, weight: .semibold))
                                .kerning(1.5)
                                .foregroundStyle(Color.textTertiary)
                            Text("\(clusters.count) spot\(clusters.count == 1 ? "" : "s")")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(Color.textPrimary)
                        }
                        Spacer()

                        // Custom locate-me button — safe area aware
                        Button {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                                cameraPosition = .userLocation(followsHeading: false, fallback: .automatic)
                            }
                            Haptics.light()
                        } label: {
                            Image(systemName: "location.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.heroPink)
                                .frame(width: 42, height: 42)
                                .background(
                                    Circle()
                                        .fill(Color(red: 0.10, green: 0.10, blue: 0.13))
                                        .overlay(Circle().strokeBorder(Color.heroPink.opacity(0.3), lineWidth: 1))
                                )
                                .shadow(color: Color.heroPink.opacity(0.3), radius: 8, x: 0, y: 3)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 56)   // below Dynamic Island / status bar
                    .padding(.bottom, 10)

                    // Category filter chips
                    categoryFilterBar
                        .padding(.bottom, 10)
                }

            }
            .navigationTitle("")
            .toolbar(.hidden, for: .navigationBar)
            .onAppear(perform: loadExpenses)
            .sheet(item: $selectedCluster) { cluster in
                LocationClusterDetailView(cluster: cluster)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Filter Bar

    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(
                    symbol: "square.grid.2x2", label: "All",
                    color: .white,
                    isSelected: activeCategoryFilter == nil
                ) { activeCategoryFilter = nil }

                ForEach(ExpenseCategory.allCases) { category in
                    filterChip(
                        symbol: category.symbolName,
                        label: category.rawValue,
                        color: category.color,
                        isSelected: activeCategoryFilter == category
                    ) {
                        activeCategoryFilter = (activeCategoryFilter == category) ? nil : category
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func filterChip(symbol: String, label: String, color: Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
        let selected = isSelected
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { action() }
            Haptics.light()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(selected ? (color == .white ? Color.black : Color.white) : color)
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(selected ? (color == .white ? Color.black : Color.white) : Color.textSecondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(selected ? color : Color.white.opacity(0.08))
                    .shadow(color: selected ? color.opacity(0.4) : .clear, radius: 8, x: 0, y: 2)
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selected)
    }

    // MARK: - Data

    private func loadExpenses() {
        let repo = ExpenseRepository(context: modelContext)
        allExpenses = (try? repo.allExpenses())?.filter { $0.hasLocation } ?? []
    }
}

// MARK: - Cluster Pin

private struct ClusterPinView: View {
    let cluster: LocationCluster

    var body: some View {
        ZStack {
            Circle()
                .fill(cluster.dominantCategory.color.opacity(0.25))
                .frame(width: pinSize + 12, height: pinSize + 12)
                .blur(radius: 7)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [cluster.dominantCategory.color, cluster.dominantCategory.color.opacity(0.65)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .frame(width: pinSize, height: pinSize)
                .overlay(Circle().strokeBorder(Color.white.opacity(0.28), lineWidth: 1.5))
                .shadow(color: cluster.dominantCategory.color.opacity(0.55), radius: 9, x: 0, y: 3)

            if cluster.visitCount > 1 {
                Text("\(cluster.visitCount)")
                    .font(.system(size: pinSize * 0.38, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            } else {
                Image(systemName: cluster.dominantCategory.symbolName)
                    .font(.system(size: pinSize * 0.42, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .transition(.scale(scale: 0.5).combined(with: .opacity))
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: cluster.visitCount)
    }

    private var pinSize: CGFloat { min(30 + CGFloat(cluster.visitCount) * 2, 52) }
}
