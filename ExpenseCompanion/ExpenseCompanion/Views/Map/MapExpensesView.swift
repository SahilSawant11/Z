//
//  MapExpensesView.swift
//  ExpenseCompanion
//
//  Shows every geotagged expense on a map. Nearby expenses are grouped into
//  clusters (via LocationInsightsEngine) so a frequently-visited cafe shows
//  one pin with a count badge instead of a dozen overlapping pins.
//

import SwiftUI
import MapKit
import SwiftData

struct MapExpensesView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var allExpenses: [Expense] = []
    @State private var cameraPosition: MapCameraPosition = .automatic
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
                Map(position: $cameraPosition, selection: .constant(nil)) {
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
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                }
                .ignoresSafeArea(edges: .bottom)

                categoryFilterBar
                    .padding(.top, 8)
            }
            .navigationTitle("Map")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                loadExpenses()
                fitCameraToClusters()
            }
            .sheet(item: $selectedCluster) { cluster in
                LocationClusterDetailView(cluster: cluster)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(label: "All", color: .primary, isSelected: activeCategoryFilter == nil) {
                    activeCategoryFilter = nil
                }
                ForEach(ExpenseCategory.allCases) { category in
                    filterChip(label: "\(category.emoji) \(category.rawValue)", color: category.color, isSelected: activeCategoryFilter == category) {
                        activeCategoryFilter = activeCategoryFilter == category ? nil : category
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func filterChip(label: String, color: Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background {
                    Capsule().fill(isSelected ? color.opacity(0.3) : Color.white.opacity(0.15))
                }
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(isSelected ? color : .clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    private func loadExpenses() {
        let repo = ExpenseRepository(context: modelContext)
        allExpenses = (try? repo.allExpenses())?.filter { $0.hasLocation } ?? []
    }

    private func fitCameraToClusters() {
        let coordinates = clusters.map(\.coordinate)
        guard !coordinates.isEmpty else { return }

        if coordinates.count == 1, let only = coordinates.first {
            cameraPosition = .region(MKCoordinateRegion(center: only, span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)))
            return
        }

        let lats = coordinates.map(\.latitude)
        let lons = coordinates.map(\.longitude)
        guard let minLat = lats.min(), let maxLat = lats.max(), let minLon = lons.min(), let maxLon = lons.max() else { return }

        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.4, 0.02),
            longitudeDelta: max((maxLon - minLon) * 1.4, 0.02)
        )
        cameraPosition = .region(MKCoordinateRegion(center: center, span: span))
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
                .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)

            if cluster.visitCount > 1 {
                Text("\(cluster.visitCount)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            } else {
                Image(systemName: cluster.dominantCategory.symbolName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .transition(.scale.combined(with: .opacity))
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: cluster.visitCount)
    }

    /// Pins scale slightly with visit count so heavily-visited spots stand out at a glance.
    private var pinSize: CGFloat {
        min(28 + CGFloat(cluster.visitCount) * 2, 48)
    }
}
