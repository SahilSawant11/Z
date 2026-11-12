//
//  MapExpensesView.swift
//  ExpenseCompanion
//
//  Map tab. Full-screen map with edge fades for legibility, auto-zoom to
//  current location, a locate button, and category filter chips.
//

import SwiftUI
import MapKit
import SwiftData

struct MapExpensesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

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

                // Top + bottom edge fades (header / tab bar protection)
                let fadeOpacity: Double = colorScheme == .dark ? 0.92 : 0.85
                VStack {
                    LinearGradient(
                        stops: [
                            .init(color: Color.appBackground, location: 0),
                            .init(color: Color.appBackground.opacity(fadeOpacity), location: 0.6),
                            .init(color: Color.clear, location: 1)
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: 320)
                    .ignoresSafeArea(edges: .top)
                    Spacer()
                    LinearGradient(
                        colors: [Color.clear, Color.appBackground.opacity(fadeOpacity * 0.8)],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: 130)
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)

                // ── Floating top bar ───────────────────────────────────────
                VStack(spacing: 0) {
                    ScreenHeader(caption: "Map", light: "Spending", bold: "\(clusters.count) spot\(clusters.count == 1 ? "" : "s")") {
                        CircleIconButton(systemName: "location.fill", filled: true) {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                                cameraPosition = .userLocation(followsHeading: false, fallback: .automatic)
                            }
                            Haptics.light()
                        }
                        .accessibilityLabel("Show my location")
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 52)   // below Dynamic Island / status bar
                    .padding(.bottom, 12)

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
        
    }

    // MARK: - Filter Bar

    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(
                    symbol: "square.grid.2x2", label: "All",
                    color: Color.textPrimary,
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
        let isAll = label == "All"
        let selectedInk: Color = isAll ? Color.appBackground : Color.onAccent
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { action() }
            Haptics.light()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(selected ? selectedInk : (isAll ? Color.textSecondary : color))
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(selected ? selectedInk : Color.textSecondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Capsule().fill(selected ? color : Color.cardSurface))
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
                .fill(cluster.dominantCategory.color)
                .frame(width: pinSize, height: pinSize)
                .overlay(Circle().strokeBorder(Color.appBackground, lineWidth: 2.5))
                .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3)

            if cluster.visitCount > 1 {
                Text("\(cluster.visitCount)")
                    .font(.system(size: pinSize * 0.38, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.onAccent)
            } else {
                Image(systemName: cluster.dominantCategory.symbolName)
                    .font(.system(size: pinSize * 0.42, weight: .semibold))
                    .foregroundStyle(Color.onAccent)
            }
        }
        .transition(.scale(scale: 0.5).combined(with: .opacity))
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: cluster.visitCount)
    }

    private var pinSize: CGFloat { min(30 + CGFloat(cluster.visitCount) * 2, 52) }
}
